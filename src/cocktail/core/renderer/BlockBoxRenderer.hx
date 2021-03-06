 /*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/
package cocktail.core.renderer;

import cocktail.core.dom.Node;
import cocktail.core.event.Event;
import cocktail.core.event.UIEvent;
import cocktail.core.event.WheelEvent;
import cocktail.core.html.HTMLElement;
import cocktail.core.html.ScrollBar;
import cocktail.core.linebox.LineBox;
import cocktail.port.NativeElement;
import cocktail.core.style.CoreStyle;
import cocktail.core.style.floats.FloatsManager;
import cocktail.core.style.formatter.BlockFormattingContext;
import cocktail.core.style.formatter.FormattingContext;
import cocktail.core.style.formatter.InlineFormattingContext;
import cocktail.core.style.StyleData;
import cocktail.core.font.FontData;
import cocktail.core.geom.GeomData;
import haxe.Log;
import cocktail.core.layer.LayerRenderer;

/**
 * A block box renderer is an element which participate
 * in a block formatting context and which can establish
 * either a block or inline formatting context.
 * 
 * When it starts an inline formatting context, it holds
 * an array of root line box which are the start of
 * each of the lines created by this block box.
 * 
 * @author Yannick DOMINGUEZ
 */
class BlockBoxRenderer extends FlowBoxRenderer
{
	/**
	 * A reference to the horizontal scrollbar which
	 * might be displayed by this BlockBoxRenderer
	 */
	private var _horizontalScrollBar:ScrollBar;
	
	/**
	 * A reference to the vertical scrollbar which
	 * might be displayed by this BlockBoxRenderer
	 */
	private var _verticalScrollBar:ScrollBar;
	
	/**
	 * Those are the bounds of the children (both in-flow and positioned)
	 * of the ElementRenderer, which are used when scrolling the
	 * content of this BlockBoxRenderer
	 */
	private var _scrollableBounds:RectangleData;
	
	/**
	 * Store the amount of scroll in the x axis of this BlockBoxRenderer
	 */
	private var _scrollLeft:Float;
	
	/**
	 * Store the amount of scroll in the y axis of this BlockBoxRenderer
	 */
	private var _scrollTop:Float;
	
	/**
	 * flag set when updating the scroll of the BlockBoxRenderer to prevent
	 * infinite loop caused by Scrollbar updating scroll
	 */
	private var _isUpdatingScroll:Bool;
	
	/**
	 * flasg set when replacing inline children by anonymous block
	 * to prevent inifinite loot caused by calls to appendChild
	 */
	private var _isMakingChildrenNonInline:Bool;
	
	/**
	 * class constructor.
	 * Init class attributes
	 */
	public function new(node:HTMLElement) 
	{
		super(node);
		
		_isUpdatingScroll = false;
		_isMakingChildrenNonInline = false;
		
		_scrollLeft = 0;
		_scrollTop = 0;
		
		_scrollableBounds = {
			x:0.0,
			y:0.0,
			width:0.0,
			height:0.0
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC METHODS
	//////////////////////////////////////////////////////////////////////////////////////////

	/**
	 * Overriden to replace inline children by anonymous block if
	 * necessary
	 */
	override public function appendChild(newChild:ElementRenderer):ElementRenderer
	{
		//flag determining wether inline children must be wrapped
		//in anonymous block
		var shouldMakeChildrenNonInline:Bool = false;
		
		var elementRendererChild:ElementRenderer = newChild;

		//if this is the first child, no need to wrap inline block
		//as it not yet known wether this block box starts an inline
		//formatting context or participates/establishes a block
		//formatting context
		if (childNodes.length > 0)
		{
			//absolutely positioned children are not taken into account when determining wether this
			//BlockBoxRenderer establishes/participate in a block or inline formatting context
			if (elementRendererChild.isPositioned() == false || elementRendererChild.isRelativePositioned() ==  true)
			{	
				//the BlockBoxRenderer should have at least one significant child to determine wether to 
				//establish/participate in a block or inline formatting context, and thus if inline children
				//shoud be wrapped in anonymous block
				if (hasSignificantChild() == true)
				{
					//if the new child is doesn't match the display of the other children,
					///for instance if it is the first inline while all the other
					//children are block, all the inline children should be wrapped
					if (elementRendererChild.isInlineLevel() != childrenInline())
					{
						shouldMakeChildrenNonInline = true;
					}
				}
			}
		}
		
		//append the new child
		super.appendChild(newChild);
		//make all children non inline if necessary
		if (shouldMakeChildrenNonInline == true)
		{	
			//check the flag to prevent infinite loop,
			//as makeChildrenNonInline itself call the 
			//appendChild method
			if (_isMakingChildrenNonInline == false)
			{
				_isMakingChildrenNonInline = true;
				makeChildrenNonInline();
				_isMakingChildrenNonInline = false;
			}
		}
	
		return newChild;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PRIVATE RENDERING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Overriden as a BlockBoxRenderer render its children and the child LayerRenderer
	 * of its LayerRenderer
	 */
	override private function renderChildren(graphicContext:NativeElement, forceRendering:Bool):Void
	{
		super.renderChildren(graphicContext, forceRendering);
		
		//the BlockBoxRenderer is responsible for rendering its children in the same stacking
		//context if it establishes a stacking context itself
		if (establishesNewStackingContext() == true)
		{
			//first render all the negative z-index child LayerRenderers
			layerRenderer.renderNegativeChildElementRenderers(graphicContext, forceRendering);
			
			//render all the block box which belong to the same stacking context
			renderBlockContainerChildren(graphicContext, forceRendering);
			
			//TODO 5 : render non-positioned float
			
			//render all the replaced (embedded) box displayed as blocks belonging
			//to the same stacking context
			renderBlockReplacedChildren(graphicContext, forceRendering);
			
			//render all the line boxes belonging to the same stacking context
			renderLineBoxes(graphicContext, forceRendering);
			
			//clip the graphic context of the block box renderer if it doesn't allow
			//overflows
			clip();
			
			//render the scrollbar if needed
			renderScrollBars(graphicContext, forceRendering);
			
			//render all the child layers with a z-index of 0 or auto
			layerRenderer.renderZeroAndAutoChildElementRenderers(graphicContext, forceRendering);
			//render all the child layer with a positive z-index
			layerRenderer.renderPositiveChildElementRenderers(graphicContext, forceRendering);
		}
		//same as above but don't render the child LayerRenderer if this 
		//block box doesn't actually establish a new stacking context
		else if (rendersAsIfEstablishingStackingContext() == true)
		{
			renderBlockContainerChildren(graphicContext, forceRendering);
			
			//TODO 5 : render non-positioned float
			renderBlockReplacedChildren(graphicContext, forceRendering);
			renderLineBoxes(graphicContext, forceRendering);
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE ANONYMOUS BLOCK METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * This method is called when all the inline children of this block
	 * box should be wrapped in anonymous block. It is done to preserve
	 * the invariant in CSS where all the children of a block box must
	 * either all be block or must all be inline. Wrapping inline children
	 * makes all the children blocks
	 */
	private function makeChildrenNonInline():Void
	{
		//will store all the current block children and the newly created
		//anonymous block, in order and will replace the current child nodes array
		var newChildNodes:Array<ElementRenderer> = new Array<ElementRenderer>();
		
		//loop in the child nodes in reverse order, as the child nodes
		//array will be modified during this loop
		var i:Int = childNodes.length -1;
		while( i >= 0)
		{
			var child:ElementRenderer = childNodes[i];

			if (child.firstChild != null)
			{
				var  fs:ElementRenderer = child.firstChild;
			}
			
			//for inline children, create an anonymous block, and attach the child to it
			if (child.isInlineLevel() == true)
			{
				//TODO 2 : only 1 anonymous block should be created for contiguous
				//inline elements
				var anonymousBlock:AnonymousBlockBoxRenderer = createAnonymousBlock(child);
				newChildNodes.push(anonymousBlock);
			}
			else
			{
				newChildNodes.push(child);
			}
			
			i--;
		}
		
		//must reverse as the child nodes where
		//looped in reverse order
		newChildNodes.reverse();
		
		//attach all the block children and the newly
		//created anonymous block box
		var length:Int = newChildNodes.length;
		for (i in 0...length)
		{
			appendChild(newChildNodes[i]);
		}
	}
	
	/**
	 * create an anonymous block and append an inline child to it
	 */ 
	private function createAnonymousBlock(child:ElementRenderer):AnonymousBlockBoxRenderer
	{
		var anonymousBlock:AnonymousBlockBoxRenderer = new AnonymousBlockBoxRenderer();
		anonymousBlock.appendChild(child);
		
		anonymousBlock.coreStyle = anonymousBlock.node.coreStyle;
		
		return anonymousBlock;
	}
	
	/**
	 * returns wether the FlowBoxRenderer has at least one significant child
	 * which can define wether he establish/participate in a block or inline
	 * formatting context.
	 * 
	 * For instance if the FlowBoxRenderer has only absolutely positioned
	 * or floated children, it can't yet know from its children wether
	 * to establish/participate in a bock or inline formatting context
	 */
	private function hasSignificantChild():Bool
	{
		var length:Int = childNodes.length;
		for (i in 0...length)
		{
			var child:ElementRenderer = childNodes[i];
			if (child.isFloat() == false)
			{
				if (child.isPositioned() == false || child.isRelativePositioned() == true)
				{
					//if at least one child child is not absolutely positioned
					//or floated, formatting context to used can be determined
					return true;
				}
			}
		}
		return false;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE RENDERING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Render all the LineBoxes of child BlockBoxRenderer which
	 * belong to the same stacking context as this BlockBoxRenderer
	 */
	private function renderLineBoxes(graphicContext:NativeElement, forceRendering:Bool):Void
	{
		//retrieve all the line boxes in all of the lines generated in this BlockBoxRenderer
		var lineBoxes:Array<LineBox> = getChilrenLineBoxes(this, layerRenderer);

		//loop in all of the lineboxes
		var length:Int = lineBoxes.length;
		for (i in 0...length)
		{
			lineBoxes[i].render(graphicContext, forceRendering);
		}
	}
	
	/**
	 * Render all the replaced children displayed as blocks which
	 * belong to the same stacking context as this BlockBoxRenderer
	 */
	private function renderBlockReplacedChildren(graphicContext:NativeElement, forceRendering:Bool):Void
	{
		var childrenBlockReplaced:Array<ElementRenderer> = getBlockReplacedChildren(this, layerRenderer);
		var length:Int = childrenBlockReplaced.length;
		for (i in 0...length)
		{
			childrenBlockReplaced[i].render(graphicContext, forceRendering);
		}
	}
	
	/**
	 * Render all the BlockBoxRenderer which
	 * belong to the same stacking context as this BlockBoxRenderer
	 */
	private function renderBlockContainerChildren(graphicContext:NativeElement, forceRendering:Bool):Void
	{
		var childrenBlockContainer:Array<ElementRenderer> = getBlockContainerChildren(this, layerRenderer);
		var length:Int = childrenBlockContainer.length;
		for (i in 0...length)
		{
			childrenBlockContainer[i].render(graphicContext, forceRendering);
		}
	}
	
	/**
	 * Render the scrollbars of this BlockBoxRenderer if needed
	 */
	private function renderScrollBars(graphicContext:NativeElement, forceRendering:Bool):Void
	{
		
		if (_horizontalScrollBar != null)
		{
			_horizontalScrollBar.elementRenderer.render(graphicContext, forceRendering);
			//updateScroll();

		}
		
		if (_verticalScrollBar != null)
		{
			_verticalScrollBar.elementRenderer.render(graphicContext, forceRendering);
			//updateScroll();
		}
	}
	
	/**
	 * Return all the line box belonging to the same
	 * stacking context as this BlockBoxRenderer
	 * 
	 * TODO 4 : can probably be simplified
	 */
	private function getChilrenLineBoxes(rootRenderer:ElementRenderer, referenceLayer:LayerRenderer):Array<LineBox>
	{
		var ret:Array<LineBox> = new Array<LineBox>();
		
		if (rootRenderer.establishesNewFormattingContext() == true && rootRenderer.childrenInline() == true)
		{
			var blockBoxRenderer:ElementRenderer = rootRenderer;
			
			var length:Int = blockBoxRenderer.lineBoxes.length;
			for (i in 0...length)
			{
				var lineBoxes:Array<LineBox> = getLineBoxesInLine(blockBoxRenderer.lineBoxes[i]);

				var childLength:Int = lineBoxes.length;
				for (j in 0...childLength)
				{
					if (lineBoxes[j].layerRenderer == referenceLayer)
					{
						ret.push(lineBoxes[j]);
					}
				}
			}
		}
		else
		{
			var length:Int = rootRenderer.childNodes.length;
			for (i in 0...length)
			{
				var child:ElementRenderer = rootRenderer.childNodes[i];
			
				if (child.layerRenderer == referenceLayer)
				{
					if (child.isReplaced() == false)
					{	
						var childLineBoxes:Array<LineBox> = getChilrenLineBoxes(child, referenceLayer);
						var childLength:Int = childLineBoxes.length;
						for (j in 0...childLength)
						{
							ret.push(childLineBoxes[j]);
						}
					}
				}
			}
		}
		
		return ret;
	}
	
	/**
	 * Return all the replaced child displayed as block belonging
	 * to the same stacking context
	 * 
	 * TODO 1 : all those methods should only be 1 method pushing into different arrays, and
	 * only called once when dom changes
	 */
	private function getBlockReplacedChildren(rootRenderer:ElementRenderer, referenceLayer:LayerRenderer):Array<ElementRenderer>
	{
		var ret:Array<ElementRenderer> = new Array<ElementRenderer>();
		
		var length:Int = rootRenderer.childNodes.length;
		for (i in 0...length)
		{
			var child:ElementRenderer = rootRenderer.childNodes[i];
			
			if (child.layerRenderer == referenceLayer && child.isPositioned() == false)
			{
				//TODO 2 : must add more condition, for instance, no float
				if (child.isReplaced() == false && child.coreStyle.display == block )
				{
					var childElementRenderer:Array<ElementRenderer> = getBlockReplacedChildren(child, referenceLayer);
					var childLength:Int = childElementRenderer.length;
					for (j in 0...childLength)
					{
						ret.push(childElementRenderer[j]);
					}
				}
				else if (child.coreStyle.display == block)
				{
					ret.push(child);
				}
			}
		}
		
		return ret;
	}
	
	/**
	 * Return all the BlockBoxRenderer children belonging
	 * to the same stacking context
	 */
	private function getBlockContainerChildren(rootRenderer:ElementRenderer, referenceLayer:LayerRenderer):Array<ElementRenderer>
	{
		var ret:Array<ElementRenderer> = new Array<ElementRenderer>();
		
		var length:Int = rootRenderer.childNodes.length;
		for (i in 0...length)
		{
			var child:ElementRenderer = rootRenderer.childNodes[i];
			//TODO 2 : this check is to prevent positioned child with a zindex of 0 from being returned, should
			//put in a method
			if (child.layerRenderer == referenceLayer && child.isPositioned() == false)
			{
				//TODO 3 : must add more condition, for instance, no float
				if (child.isReplaced() == false && child.coreStyle.display != inlineBlock)
				{
					ret.push(child);
					
					var childElementRenderer:Array<ElementRenderer> = getBlockContainerChildren(child, referenceLayer);
					var childLength:Int = childElementRenderer.length;
					for (j in 0...childLength)
					{
						ret.push(childElementRenderer[j]);
					}
				}
			}
		}
		return ret;
	}
	
	/////////////////////////////////
	// OVERRIDEN PUBLIC VISUAL EFFECT METHODS
	////////////////////////////////
	
	//TODO 2 : doc
	override public function scroll(x:Float, y:Float):Void
	{
		super.scroll(x, y);
		//TODO 2 : should be applied to every positioned element whose
		//containing block is a parent of the root renderer.
		//Add a public method on ElementRenderer ?
		if (_horizontalScrollBar != null || _verticalScrollBar != null)
		{
			#if (flash9 || nme)
			
			var width:Float;
			var height:Float;
			
			if (graphicsContext.scrollRect != null)
			{
				width = graphicsContext.scrollRect.width;
				height = graphicsContext.scrollRect.height;
			}
			else
			{
				width =  globalBounds.width;
				height = globalBounds.height;
			}
			
			graphicsContext.scrollRect = new flash.geom.Rectangle(x , y, width + globalBounds.x, height + globalBounds.y);
			#end
			scrollChildren(this, x, y);
		}
		
	}
	
	/////////////////////////////////
	// PRIVATE VISUAL EFFECT METHODS
	////////////////////////////////
	
	/**
	 * Clip the bounds of the graphic context
	 * of this BlockBoxRenderer according to the 
	 * overflow style.
	 */
	private function clip():Void
	{
		#if (flash9 || nme)
		
		var scrollableContainerBlock:ContainingBlockData = getScrollbarContainerBlock();
		
			if (isXAxisClipped() == true && isYAxisClipped() == true)
			{
				var globalBounds:RectangleData = globalBounds;
				graphicsContext.scrollRect = new flash.geom.Rectangle(0 , 0, scrollableContainerBlock.width + globalBounds.x, scrollableContainerBlock.height + globalBounds.y);

			}
			else if (isXAxisClipped() == true)
			{
				//TODO 2 : how to prevent clipping in one direction ? 10000 might not be enougn for scrollable content
				graphicsContext.scrollRect = new flash.geom.Rectangle(0 , 0, scrollableContainerBlock.width, 10000);
		
			}
			else if (isYAxisClipped() == true)
			{
				//TODO 2 : how to prevent clipping in one direction ? 10000 might not be enougn for scrollable content
				graphicsContext.scrollRect = new flash.geom.Rectangle(0 , 0, 10000, scrollableContainerBlock.height);
			}
			else
			{
				graphicsContext.scrollRect = null;
			}
			
		#end	
	}
	
	
	//TODO 1 : hack to make fixed positioned element displayed correctly when in a
	//a scrolled container. For some reason, don't work for auto z-index positioned element
	private function scrollChildren(root:ElementRenderer, scrollX:Float, scrollY:Float):Void
	{
		var length:Int = root.childNodes.length;
		for ( i in 0...length)
		{
			//var child:ElementRenderer = root.childNodes[i];
			//if (child.computedStyle.position == fixed || child.isScrollBar())
			//{
				//child.scroll(scrollX, scrollY);
			//}
			//else if (child.hasChildNodes() == true )
			//{
				//scrollChildren(child, scrollX, scrollY);
			//}
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC LAYOUT METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Overriden to deal with the scrollbars once the children of this
	 * BlockBoxRenderer are laid out
	 */
	override public function layout(forceLayout:Bool):Void
	{	
		super.layout(forceLayout);
		
		//only get scrollable bounds for bloc box renderer
		//which might display scrollbars
		if (canAlwaysOverflow() == false)
		{
			_scrollableBounds = getScrollableBounds();
		}
		
		var isVerticalScrollAttached:Bool = _verticalScrollBar != null;
		var isHorizontalScrollAttached:Bool = _horizontalScrollBar != null;
		
		attachScrollBarsIfnecessary();
		
		if (isVerticalScrollAttached != (_verticalScrollBar != null) || isHorizontalScrollAttached != (_horizontalScrollBar != null) )
		{
			_needsLayout = true;
			_childrenNeedLayout = true;
			super.layout(forceLayout);
		}
		
		layoutScrollBarsIfNecessary(getWindowData());
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PRIVATE LAYOUT METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * starts the formatting of this block box if it
	 * establishes a new formatting context.
	 */
	override private function format():Void
	{
		if (establishesNewFormattingContext() == true )
		{
			if (isPositioned() == true && isRelativePositioned() == false)
			{
				doFormat();
			}
			else if (isFloat() == true)
			{
				doFormat();
			}
			else if (computedStyle.display == inlineBlock)
			{
				doFormat();
			}
			else if (childrenInline() == false)
			{
				doFormat();
			}
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE LAYOUT METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Actually starts formatting this BlockBoxRenderer
	 * if it indeed establishes a new formatting context.
	 * 
	 * Instantiate the right formatting context, based
	 * on the display of the children
	 */
	private function doFormat():Void
	{
		if (childrenInline() == true)
		{
			new InlineFormattingContext(this).format(new FloatsManager());
		}
		else
		{
			new BlockFormattingContext(this).format(new FloatsManager());
		}
	}
	
	//TODO 4 : more complex thant it should
	private function layoutScrollBarsIfNecessary(viewportData:ContainingBlockData):Void
	{
		var horizontalScrollBarContainerBlockData = getContainerBlockData();
		
		if (_horizontalScrollBar != null)
		{
			horizontalScrollBarContainerBlockData.height += _horizontalScrollBar.coreStyle.computedStyle.height;
		}
		
		if (_horizontalScrollBar != null)
		{	
			layoutPositionedChild(_horizontalScrollBar.elementRenderer, horizontalScrollBarContainerBlockData, viewportData);
		}
		
		var verticalScrollBarContainerBlockData = getContainerBlockData();
		
		if (_verticalScrollBar != null)
		{
			verticalScrollBarContainerBlockData.width += _verticalScrollBar.coreStyle.computedStyle.width;
		}
		
		if (_verticalScrollBar != null)
		{
			layoutPositionedChild(_verticalScrollBar.elementRenderer, verticalScrollBarContainerBlockData, viewportData);
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN SCROLLING GETTERS/SETTERS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Overriden as BlockBoxRenderer might actually be scrolled
	 */
	override private function get_scrollLeft():Float 
	{
		return _scrollLeft;
	}
	
	/**
	 * Overriden as BLockBoxRenderer might actually be scrolled
	 */
	override private function set_scrollLeft(value:Float):Float 
	{
		//negative values are illegal
		if (value <= 0)
		{
			_scrollLeft = 0;
		}
		//if the value if more the available scrollable width, set
		//the value to the max scrollable width
		else if (value > getHorizontalMaxScroll())
		{
			_scrollLeft = getHorizontalMaxScroll();
		}
		else
		{
			_scrollLeft = value;
		}
		
		updateScroll();
		
		return value;
	}
	
	override private function get_scrollTop():Float 
	{
		return _scrollTop;
	}
	
	override private function set_scrollTop(value:Float):Float 
	{
		if (value <= 0)
		{
			_scrollTop = 0;
		}
		else if (value > getVerticalMaxScroll())
		{
			_scrollTop = getVerticalMaxScroll();
		}
		else
		{
			_scrollTop = value;
		}
		
		updateScroll();
		
		return value;
	}
	
	/**
	 * overriden as the scroll width for a block
	 * box might be its scrollable bounds width
	 * 
	 * TODO 4 : should it be only when scrollbars are
	 * displayed ?
	 */
	override private function get_scrollWidth():Float
	{
		if (_scrollableBounds.width > bounds.width)
		{
			return _scrollableBounds.width;
		}
		
		return bounds.width;
	}
	
	override private function get_scrollHeight():Float
	{
		if (_scrollableBounds.height > bounds.height)
		{
			return _scrollableBounds.height;
		}
		
		return bounds.height;
	}
	
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE SCROLLING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Determine wheter the x axis of this BlockBoxRenderer
	 * is clipped to its width
	 */
	private function isXAxisClipped():Bool
	{
		switch (computedStyle.overflowX)
		{
			case Overflow.hidden,
			Overflow.scroll:
				return true;
				
			//when overflow is auto, the x axis is only
			//clipped if a scrollbar was attached
			case Overflow.cssAuto:
				return _horizontalScrollBar != null;
				
			case Overflow.visible:
				if (treatVisibleOverflowAsAuto() == true)
				{
					return _horizontalScrollBar != null;
				}
				return false;
		}
	}
	
	/**
	 * Determine wheter the y axis of this BlockBoxRenderer
	 * is clipped to its height
	 */
	private function isYAxisClipped():Bool
	{
		switch (computedStyle.overflowY)
		{
			case Overflow.hidden,
			Overflow.scroll:
				return true;
				
			case Overflow.cssAuto:
				return _verticalScrollBar != null;
				
			case Overflow.visible:
				if (treatVisibleOverflowAsAuto() == true)
				{
					return _verticalScrollBar != null;
				}
				return false;
		}
	}
	
	/**
	 * When a scroll value changes, update the rendering
	 */
	private function updateScroll():Void
	{
		//only called if not already updating scroll, else
		//infinite loop with scrollbars
		if (_isUpdatingScroll == false)
		{
			_isUpdatingScroll = true;
			
			if (isXAxisClipped() == true || isYAxisClipped() == true)
			{
				scroll(_scrollLeft, _scrollTop);
			}
			
			if (_horizontalScrollBar != null)
			{
				_horizontalScrollBar.scroll = scrollLeft;
			}
			if (_verticalScrollBar != null)
			{
				_verticalScrollBar.scroll = scrollTop;
			}
			
			//when scrolling is done, dispatched a scroll
			//event on the dom node
			dispatchScrollEvent();
			
			_isUpdatingScroll = false;
		}
	}
	
	//TODO 2 : should manage the following case : 
	// - child is relative positioned,
	// - child is absolute positioned
	// - child is fixed positioned or absolute positoned but 
	// block container is parent of this block box renderer and it must
	// not be scrolled and clipped. ElementRenderer should be able to know
	//their containing block
	
	/**
	 * Get the bounds of all of the children of this BlockBoxRenderer
	 */
	private function getScrollableBounds():RectangleData
	{
		return getChildrenBounds(doGetScrollableBounds(this));
	}
	
	//TODO 2 : work but shouldn't have to parse all rendering tree, should be done during formatting
	//and then another pass for absolutely positioned children. Maybe this way less expensive in
	//the  end because only called when useful ?
	/**
	 * Get the bounds of all of the children
	 * by traversing the rendering tree
	 */
	private function doGetScrollableBounds(rootRenderer:ElementRenderer):Array<RectangleData>
	{
		var childrenBounds:Array<RectangleData> = new Array<RectangleData>();

		var length:Int = rootRenderer.childNodes.length;
		for (i in 0...length)
		{
			
			var child:ElementRenderer = rootRenderer.childNodes[i];
				
			if (child.node != _horizontalScrollBar && child.node != _verticalScrollBar)
			{
				if (child.hasChildNodes() == true)
				{
					var childChildrenBounds:Array<RectangleData> = doGetScrollableBounds(child);
					
					var childLength:Int = childChildrenBounds.length;
					for (j in 0...childLength)
					{
						childrenBounds.push(childChildrenBounds[j]);
					}
				}
				
				childrenBounds.push(child.scrollableBounds);
			}
		}
		return childrenBounds;
	}
	
	//TODO 3 : implement border case where one has scroll attached, and the 
	//other is visible but should still display scroll
	/**
	 * Attach the horizontal and vertical scrollbar if they are
	 * needed, based on the overflow style of the BlockBoxRenderer
	 */
	private function attachScrollBarsIfnecessary():Void
	{
		//only try to remove attached scrollbars if both
		//overflow x and y are set to visible
		if (canAlwaysOverflow() == true)
		{
			detachHorizontalScrollBar();
			detachVerticalScrollBar();
			return;
		}
		
		//tries to attach or detach horizontal scrollbar based on x
		//overflow
		switch (computedStyle.overflowX)
		{
			case Overflow.scroll:
				attachHorizontalScrollBar();
				
			case hidden:
				detachHorizontalScrollBar();
				
			case cssAuto:
				attachOrDetachHorizontalScrollBarIfNecessary();
				
			case visible:
				if (treatVisibleOverflowAsAuto() == true)
				{
					attachOrDetachHorizontalScrollBarIfNecessary();
				}
				else
				{
					detachHorizontalScrollBar();
				}
		}

		//tries to attach or detach vertical scrolbar based on 
		//overflow y
		switch (computedStyle.overflowY)
		{
			case Overflow.scroll:
				attachVerticalScrollBar();
				
			case hidden:
				detachVerticalScrollBar();
				
			case cssAuto:
				attachOrDetachVerticalScrollBarIfNecessary();
				
			case visible:
				if (treatVisibleOverflowAsAuto() == true)
				{
					attachOrDetachVerticalScrollBarIfNecessary();
				}	
				else
				{
					detachVerticalScrollBar();
				}
		}
	}
	
	/**
	 * Instantiate the horizontal scrollbar DOM element
	 * and attach it to the rendering tree, if it isn't
	 * already attached
	 * 
	 * Listen to scroll event on it to update the
	 * scroll display as needed
	 */
	private function attachHorizontalScrollBar():Void
	{
		if (_horizontalScrollBar == null)
		{
			_horizontalScrollBar = new ScrollBar(false);
			_horizontalScrollBar.ownerDocument = node.ownerDocument;
			_horizontalScrollBar.attach();
			appendChild(_horizontalScrollBar.elementRenderer);
			_horizontalScrollBar.onscroll = onHorizontalScroll;
		}
		//refresh the max scroll when a layout of the BlockBoxRenderer happens
		if (_horizontalScrollBar != null)
		{
			_horizontalScrollBar.maxScroll = getHorizontalMaxScroll();
		}
	}
	
	/**
	 * Detach the horizontal scrollbar if it is 
	 * currently displayed
	 */
	private function detachHorizontalScrollBar():Void
	{
		if (_horizontalScrollBar != null)
		{
			removeChild(_horizontalScrollBar.elementRenderer);
			_horizontalScrollBar.onscroll = null;
			_horizontalScrollBar = null;
			
			//reset scroll so that the display don't "jump" if
			//the horizontal scrollbar is attached again
			scrollLeft = 0;
		}
	}
	
	/**
	 * When overflow x is set to auto, only try to attach the horizontal scrollbar
	 * if the children width is superior to the BlockBoxRenderer width, else
	 * try to detach it
	 */
	private function attachOrDetachHorizontalScrollBarIfNecessary():Void
	{
		if (_scrollableBounds.x < 0 || _scrollableBounds.x + _scrollableBounds.width > bounds.width)
		{
			attachHorizontalScrollBar();
		}
		else
		{
			detachHorizontalScrollBar();
		}
	}
	
	/**
	 * same as for horizontal scrollbar
	 */
	private function attachVerticalScrollBar():Void
	{
		if (_verticalScrollBar == null)
		{
			_verticalScrollBar = new ScrollBar(true);
			_verticalScrollBar.ownerDocument = node.ownerDocument;
			_verticalScrollBar.attach();
			appendChild(_verticalScrollBar.elementRenderer);
			_verticalScrollBar.onscroll = onVerticalScroll;
		}
		if (_verticalScrollBar != null)
		{
			_verticalScrollBar.maxScroll = getVerticalMaxScroll();
		}
	}
	
	/**
	 * same as for horizontal scrollbar
	 */
	private function detachVerticalScrollBar():Void
	{
		if (_verticalScrollBar != null)
		{
			removeChild(_verticalScrollBar.elementRenderer);
			_verticalScrollBar.onscroll = null;
			_verticalScrollBar = null;
			
			//reset scroll so that the display don't "jump" if
			//the vertical scrollbar is attached again
			scrollTop = 0;
		}
	}
	
	/**
	 * same as for horizontal scrollbar
	 */
	private function attachOrDetachVerticalScrollBarIfNecessary():Void
	{
		if (_scrollableBounds.y < 0 || _scrollableBounds.y + _scrollableBounds.height >  bounds.height)
		{
			attachVerticalScrollBar();
		}
		else
		{
			detachVerticalScrollBar();
		}
	}
	
	/**
	 * Update scroll left when a scroll event
	 * is displateched by the horizontal scrollbar
	 */
	private function onHorizontalScroll(event:Event):Void
	{
		scrollLeft = _horizontalScrollBar.scroll;
	}
	
	/**
	 * same as for horizontal scrollbar
	 */
	private function onVerticalScroll(event:Event):Void
	{
		scrollTop = _verticalScrollBar.scroll;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC HELPER METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Overriden as BlockBoxRenderer can also starts a new stacking context
	 * if the overflow x or y style value is different from visible
	 */
	override public function establishesNewStackingContext():Bool
	{
		var establishesNewStackingContext:Bool = super.establishesNewStackingContext();
		
		if (establishesNewStackingContext == true)
		{
			return true;
		}
		
		return canAlwaysOverflow() != true;
	}
	
	/**
	 * Wether a vertical active scrollbar is displayed and
	 * scrollable. It is not considered scrollable if the
	 * provided scroll offset wouldn't make it scroll, for
	 * intance if scrollTop is 0 and the provided offset is -10,
	 * it won't make it scroll
	 * 
	 * TODO 3 : must return false if scrollbar disabled
	 */
	override public function isVerticallyScrollable(scrollOffset:Int):Bool
	{
		if (_verticalScrollBar == null)
		{
			return false;
		}
		if (scrollOffset < 0)
		{
			if (scrollTop >= _scrollableBounds.height - getContainerBlockData().height)
			{
				return false;
			}
		}
		else if (scrollOffset > 0)
		{
			if (scrollTop <= 0)
			{
				return false;
			}
		}
		
		return true;
	}
	
	/**
	 * same as above for horizontal scrollbar
	 */
	override public function isHorizontallyScrollable(scrollOffset:Int):Bool
	{
		if (_horizontalScrollBar == null)
		{
			return false;
		}
		
		if (scrollOffset < 0)
		{
			if (scrollLeft >= _scrollableBounds.width - getContainerBlockData().width)
			{
				return false;
			}
		}
		else if (scrollOffset > 0)
		{
			if (scrollLeft <= 0)
			{
				return false;
			}
		}
		
		return true;
	}
	
	/**
	 * Determine wether the ElementRenderer
	 * establishes a new formatting context for
	 * its children or participate in its
	 * parent formatting context
	 */
	override public function establishesNewFormattingContext():Bool
	{
		var establishesNewFormattingContext:Bool = false;
		
		//floats always establishes new formatting context
		if (isFloat() == true)
		{
			establishesNewFormattingContext = true;
		}
		//block box renderer which may use scrollbars to display
		//their children always establishes a new formatting context
		else if (canAlwaysOverflow() == false)
		{
			establishesNewFormattingContext = true;
		}
		//positioned element which are not relative always establishes new context
		else if (isPositioned() == true && isRelativePositioned() == false)
		{
			establishesNewFormattingContext = true;
		}
		//anonymous block always establish new inline formatting as they are used 
		//to wrap inline elements in block formatting
		else if (isAnonymousBlockBox() == true)
		{
			establishesNewFormattingContext = true;
		}
		else
		{
			switch (this.computedStyle.display)
			{
				//element with an inline-block display style
				//always establishes a new context
				case inlineBlock:
				establishesNewFormattingContext = true; 
				
				//a block ElementRenderer may start a new inline
				//formatting context if all its children are inline,
				//else it participates in the current block formatting
				//context
				case block:
					if (childrenInline() == true)
					{
						establishesNewFormattingContext = true;
					}
					
				default:
			}
		}
		
		//in the other cases, the block particpates in its parent's
		//formatting context
		
		return establishesNewFormattingContext;
	}
	
	override public function isBlockContainer():Bool
	{
		return true;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PRIVATE HELPER METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * overriden as a block box renderer might be rendered as if
	 * establishing stacking context, based on its computed styles
	 * value
	 */
	override private function rendersAsIfEstablishingStackingContext():Bool
	{
		//if z-index is 0 or auto and the ElementRenderer
		//is positioned
		if (isAutoZIndexPositioned() == true)
		{
			return true;
		}
		else if (computedStyle.display == inlineBlock)
		{
			return true;
		}
		else if (isFloat() == true)
		{
			return true;
		}
		
		return false;
	}
	
	/**
	 * Overriden, as if scrollbars are displayed, their 
	 * width or height must be substracted from the containing
	 * block width/height
	 */
	override public function getContainerBlockData():ContainingBlockData
	{
		var height:Float = this.computedStyle.height;
		if (_horizontalScrollBar != null)
		{
			height -= _horizontalScrollBar.coreStyle.computedStyle.height;
		}
		
		var width:Float = this.computedStyle.width;
		if (_verticalScrollBar != null)
		{
			width -= _verticalScrollBar.coreStyle.computedStyle.width;
		}
		
		return {
			width:width,
			isWidthAuto:this._coreStyle.width == Dimension.cssAuto,
			height:height,
			isHeightAuto:this._coreStyle.height == Dimension.cssAuto
		};
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE HELPER METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Utils method to return the containing block data
	 * without any scrollbars. Used when positioning scrollbars
	 * themselves
	 */
	private function getScrollbarContainerBlock():ContainingBlockData
	{
		return super.getContainerBlockData();
	}
	
	/**
	 * Return the maximum amount of scroll in pixels in the
	 * vertical direcion. Maximum scroll can't be negative
	 */
	private function getVerticalMaxScroll():Float
	{
		var maxScroll:Float = _scrollableBounds.height - getContainerBlockData().height;
		
		//if the container is higher than its children, 
		//then it can't be scrolled
		if (maxScroll < 0)
		{
			return 0;
		}
		
		return maxScroll;
	}
	
	/**
	 * Same as above for horizontal max scroll
	 */
	private function getHorizontalMaxScroll():Float
	{
		var maxScroll:Float = _scrollableBounds.width - getContainerBlockData().width;
		
		if (maxScroll < 0)
		{
			return 0;
		}
		
		return maxScroll;
	}
	
	/**
	 * Utils method dispatching a Scroll event
	 * on the dom node after a scrolling occured
	 */
	private function dispatchScrollEvent():Void
	{
		var scrollEvent:UIEvent = new UIEvent();
		scrollEvent.initUIEvent(UIEvent.SCROLL, mustBubbleScrollEvent(), false, null, 0.0);
		node.dispatchEvent(scrollEvent);
	}
	
	/**
	 * Utils method determining wether the dispatched scroll
	 * event must bubble. Scroll event only bubbles 
	 * when dispatched on the HTMLHTMLElement, as it
	 * needs to bubble to the Document and Window
	 * objects
	 */
	private function mustBubbleScrollEvent():Bool
	{
		return false;
	}
	
	/**
	 * Determine wether this BlockBoxRenderer always overflows
	 * in both x and y axis. If either overflow x or y
	 * is deifferent from visible, then it is considered to
	 * not always overflow
	 */
	private function canAlwaysOverflow():Bool
	{
		if (treatVisibleOverflowAsAuto() == true)
		{
			return false;
		}
		
		switch (computedStyle.overflowX)
		{
			case Overflow.visible:
				
				
			default:
				return false;
		}
		
		switch (computedStyle.overflowY)
		{
			case Overflow.visible:
				
			default:
				return false;
		}
		
		return true;
	}
	
	/**
	 * This helper method is used to differentiate between
	 * a block box renderer and the initial block box renderer.
	 * 
	 * For the initial block box renderer, a computed value
	 * of visible for overflow behaves the same as a computed
	 * value of auto
	 */
	private function treatVisibleOverflowAsAuto():Bool
	{
		return false;
	}
}