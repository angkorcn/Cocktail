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
import cocktail.core.html.HTMLElement;
import cocktail.core.linebox.LineBox;
import cocktail.core.style.ComputedStyle;
import cocktail.core.style.formatter.FormattingContext;
import cocktail.core.style.StyleData;
import cocktail.core.geom.GeomData;
import cocktail.core.font.FontData;

/**
 * This is a base class for ElementRenderer which are
 * container such as the block box and inline box.
 * 
 * It takes cares of laying out its children
 * 
 * @author Yannick DOMINGUEZ
 */
class FlowBoxRenderer extends BoxRenderer 
{
	
	private var _positionedChildren:Array<ElementRenderer>;
	
	/**
	 * class constructor
	 */
	public function new(node:HTMLElement) 
	{
		super(node);
		_positionedChildren = new Array<ElementRenderer>();
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE RENDERING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Return all the LineBoxes created by this ElementRenderer
	 * in one line, as an array of LineBoxes
	 */
	private function getLineBoxesInLine(rootLineBox:LineBox):Array<LineBox>
	{
		var ret:Array<LineBox> = new Array<LineBox>();
		
		var length:Int = rootLineBox.childNodes.length;
		for (i in 0...length)
		{
			ret.push(rootLineBox.childNodes[i]);
			
			if (rootLineBox.childNodes[i].hasChildNodes() == true)
			{
				var childLineBoxes:Array<LineBox> = getLineBoxesInLine(rootLineBox.childNodes[i]);
				
				var childLength:Int = childLineBoxes.length;
				for (j in 0...childLength)
				{
					ret.push(childLineBoxes[j]);
				}
			}
		}
		return ret;
	}
	
	public function addPositionedChildren(element:ElementRenderer):Void
	{
		_positionedChildren.push(element);
	}
	
	public function removePositionedChild(element:ElementRenderer):Void
	{
		_positionedChildren.remove(element);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PRIVATE LAYOUT METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	override public function layout(forceLayout:Bool):Void
	{
		super.layout(forceLayout);
		
		/**
		 * Actually layout all the children of the ElementRenderer by calling
		 * the layout method recursively on all the children
		 */
		var length:Int = childNodes.length;
		for (i in 0...length)
		{
			childNodes[i].layout(_childrenNeedLayout);
		}
		
		//starts the formatting of the children of this FlowBoxRenderer
		//if it establishes a new formatting context
		//
		//TODO 3 : should only be called for BlockBoxRenderer
		format();
		
		if (_positionedChildrenNeedLayout == true || forceLayout == true)
		{
			//if this ElementRenderer is positioned, it means that it is the first positioned ancestor
			//for its positioned children and it is its responsability to lay them out
			if (isPositioned() == true)
			{
				layoutPositionedChildren();
			}
			_positionedChildrenNeedLayout = false;
		}
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE LAYOUT METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	private function layoutPositionedChildren():Void
	{
		var containerBlockData:ContainingBlockData = getContainerBlockData();
		var windowData:ContainingBlockData = getWindowData();
		
		//lay out each stored children
		var length:Int = _positionedChildren.length;
		for (i in 0...length)
		{
			//layout the child ElementRenderer which set its x and y positioned origin in the space of this ElementRenderer's
			//positioned origin
			layoutPositionedChild(_positionedChildren[i], containerBlockData, windowData);
		}
	}
	
	/**
	 * starts the formatting of the box
	 */
	private function format():Void
	{
		//abstract
	}
	
	/**
	 * layout an absolutely positioned ElementRenderer (with a position style of 'fixed' or 'absolute')
	 * using either the first positioned ancestor dimensions or the viewport's
	 * 
	 * @param firstPositionedAncestorData the dimensions of the first positioned ancestor
	 * @param viewportData the dimensions of the viewport
	 */
	private function layoutPositionedChild(elementRenderer:ElementRenderer, firstPositionedAncestorData:ContainingBlockData, viewportData:ContainingBlockData):Void
	{
		switch (elementRenderer.computedStyle.position)
		{	
			//positioned 'fixed' ElementRenderer, use the viewport
			case fixed:
				doLayoutPositionedChild(elementRenderer, viewportData);
				
			//positioned 'absolute' ElementRenderer use the first positioned ancestor data	
			case absolute:
				doLayoutPositionedChild(elementRenderer, firstPositionedAncestorData);
				
			default:
		}
	}
	
	/**
	 * Actually lay out the positioned ElementRenderer
	 */
	private function doLayoutPositionedChild(elementRenderer:ElementRenderer, containingBlockData:ContainingBlockData):Void
	{
		//for horizonal offset, if both left and right are not auto,
		//left takes precedance so we try to apply left offset first
		if (elementRenderer.coreStyle.left != PositionOffset.cssAuto)
		{
			elementRenderer.positionedOrigin.x = getLeftOffset(elementRenderer);
		}
		//if no left offset is defined, then try to apply a right offset.
		//Right offset takes the containing block width minus the
		//width of the positioned children as value for a 0 right offset
		else if (elementRenderer.coreStyle.right != PositionOffset.cssAuto)
		{
			elementRenderer.positionedOrigin.x = getRightOffset(elementRenderer, containingBlockData.width);
		}
		//if both right and left are 'auto', then the ElementRenderer is positioned to its
		//static position, the position it would have had in the flow if it were positioned as 'static'.
		//At this point the bounds of the ElementRenderer already matches its static position
		
		//for vertical offset, the same rule as horizontal offsets apply
		if (elementRenderer.coreStyle.top != PositionOffset.cssAuto)
		{
			elementRenderer.positionedOrigin.y = getTopOffset(elementRenderer);
		}
		else if (elementRenderer.coreStyle.bottom != PositionOffset.cssAuto)
		{
			elementRenderer.positionedOrigin.y = getBottomOffset(elementRenderer, containingBlockData.height);
		}
	}
	
	/**
	 * get the left offset to apply the ElementRenderer
	 */
	private function getLeftOffset(elementRenderer:ElementRenderer):Float
	{
		var computedStyle:ComputedStyle = elementRenderer.coreStyle.computedStyle;
		return computedStyle.left + computedStyle.marginLeft;
	}
	
	/**
	 * get the right offset to apply the ElementRenderer
	 */
	private function getRightOffset(elementRenderer:ElementRenderer, containingHTMLElementWidth:Float):Float
	{
		var computedStyle:ComputedStyle = elementRenderer.coreStyle.computedStyle;
		return containingHTMLElementWidth - computedStyle.width - computedStyle.paddingLeft
		- computedStyle.paddingRight - computedStyle.right - computedStyle.marginRight;
	}
	
	/**
	 * get the top offset to apply the ElementRenderer
	 */
	private function getTopOffset(elementRenderer:ElementRenderer):Float
	{
		var computedStyle:ComputedStyle = elementRenderer.coreStyle.computedStyle;
		return computedStyle.top + computedStyle.marginTop;
	}
	
	/**
	 * get the bottom offset to apply the ElementRenderer
	 */
	private function getBottomOffset(elementRenderer:ElementRenderer, containingHTMLElementHeight:Float):Float
	{
		var computedStyle:ComputedStyle = elementRenderer.coreStyle.computedStyle;
		return containingHTMLElementHeight - computedStyle.height - computedStyle.paddingTop -
		computedStyle.paddingBottom - computedStyle.bottom;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERIDEN PUBLIC HELPER METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Determine wether the children of this ElementRenderer
	 * are all block level or if they are all inline level
	 * elements
	 * 
	 * @return true if at least one child is inline level
	 */
	override public function childrenInline():Bool
	{	
		var length:Int = childNodes.length;
		
		for (i in 0...length)
		{
			var child:ElementRenderer = childNodes[i];
			//floated and absolutely positioned element are not taken into
			//account
			if (child.isFloat() == false)
			{
				if (child.isPositioned() == false || child.isRelativePositioned() == true)
				{
					if (child.isInlineLevel() == true)
					{
						return true;
					}
				}
			}
		}
		return false;
	}
}