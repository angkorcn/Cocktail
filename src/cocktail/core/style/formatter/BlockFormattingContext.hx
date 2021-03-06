/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/
package cocktail.core.style.formatter;
import cocktail.core.dom.Node;
import cocktail.core.style.ComputedStyle;
import cocktail.core.style.CoreStyle;
import cocktail.core.style.StyleData;
import cocktail.core.geom.GeomData;
import cocktail.core.renderer.BlockBoxRenderer;
import cocktail.core.renderer.ElementRenderer;
import haxe.Log;

/**
 * This formatting context layout HTMLElement below each other
 * generally following the formattable tree order.
 * 
 * There might be exception, for instance if a container HTMLElement
 * with a fixed has overflowing children, its siblings will use
 * the height of the container to be positioned below, not the
 * added height of its children.
 * 
 * @author Yannick DOMINGUEZ
 */
class BlockFormattingContext extends FormattingContext
{

	private var _registeredFloats:Array<FloatData>;

	/**
	 * class constructor
	 */
	public function new(formattingContextRoot:BlockBoxRenderer) 
	{
		super(formattingContextRoot);
		_registeredFloats = new Array<FloatData>();
	}

	override private function startFormatting():Void
	{
		//remove margin of formatting context, as child must be placed relative to padding box
		doFormat(_formattingContextRoot, - _formattingContextRoot.coreStyle.computedStyle.marginLeft, - _formattingContextRoot.coreStyle.computedStyle.marginTop, 0, _formattingContextRoot.coreStyle.computedStyle.marginTop,  _formattingContextRoot.coreStyle.computedStyle.marginBottom);
	}

	//TODO 1 : should be on FloatManager
	private function isFloatRegistered(child:ElementRenderer):Bool
	{
		var length:Int = _registeredFloats.length;
		for (i in 0...length)
		{
			if (_registeredFloats[i].node == child)
			{
				return true;
			}
		}

		return false;
	}

	private function getRegisteredFloat(child:ElementRenderer):FloatData
	{
		var length:Int = _registeredFloats.length;
		for (i in 0...length)
		{
			if (_registeredFloats[i].node == child)
			{
				return _registeredFloats[i];
			}
		}

		return null;
	}

	private function doFormat(elementRenderer:ElementRenderer, concatenatedX:Float, concatenatedY:Float, currentLineY:Float, parentCollapsedMarginTop:Float, parentCollapsedMarginBottom:Float):Float
	{
		var elementRendererComputedStyle:ComputedStyle = elementRenderer.coreStyle.computedStyle;

		concatenatedX += elementRendererComputedStyle.paddingLeft  + elementRendererComputedStyle.marginLeft;

		concatenatedY += elementRendererComputedStyle.paddingTop + parentCollapsedMarginTop;

		var childHeight:Float = concatenatedY;

		var length:Int = elementRenderer.childNodes.length;
		for (i in 0...length)
		{
			var child:ElementRenderer = elementRenderer.childNodes[i];

			var marginTop:Float = getCollapsedMarginTop(child, parentCollapsedMarginTop);
			var marginBottom:Float = getCollapsedMarginBottom(child, parentCollapsedMarginBottom);

			var computedStyle:ComputedStyle = child.coreStyle.computedStyle;
			var width:Float = computedStyle.width + computedStyle.paddingLeft + computedStyle.paddingRight;
			var height:Float = computedStyle.height + computedStyle.paddingTop + computedStyle.paddingBottom;

			var x:Float = concatenatedX + child.coreStyle.computedStyle.marginLeft;
			var y:Float = concatenatedY + marginTop;

			var childBounds:RectangleData = child.bounds;
			childBounds.x = x;
			childBounds.y = y;
			childBounds.width = width;
			childBounds.height = height;

			if (child.isFloat() == true)
			{
				//TODO 1 : floats should use currentLineY instead, else, if a floated
				//element is declared after an inline one, it won't be on the right line
				if (isFloatRegistered(child) == false)
				{
					var floatBounds:RectangleData = _floatsManager.registerFloat(child, concatenatedY, 0, elementRendererComputedStyle.width);
					_registeredFloats.push( {
						node:child, 
						bounds:floatBounds
					});

					format(_floatsManager);
					return 0.0;
				}

				var floatBounds:RectangleData = getRegisteredFloat(child).bounds;

				childBounds.x = floatBounds.x + computedStyle.marginLeft;
				childBounds.y = floatBounds.y + computedStyle.marginTop;
				childBounds.x += concatenatedX;

			}
			//for child with children of their own, their padding and margin are added at
			//the beginning of the recursive method
			else if (child.hasChildNodes() == true)
			{
				//children starting their own formatting context are not laid out
				//by this formatting context
				if (child.establishesNewFormattingContext() == false)
				{
					currentLineY = child.bounds.y;
					concatenatedY = doFormat(child, concatenatedX, concatenatedY, currentLineY, marginTop, marginBottom);
				}
				else 
				{
					if ((child.isPositioned() == false || child.isRelativePositioned() == true) && child.isFloat() == false)
					{
						//TODO 1 : doc, now block formatting context in charge of formatting line
						//boxes, because of floats
						if (child.childrenInline() == true)
						{
							var inlineFormattingContext:InlineFormattingContext = new InlineFormattingContext(cast(child));
							inlineFormattingContext.format(_floatsManager);
						}				

						currentLineY = child.bounds.y;
						concatenatedY += child.bounds.height + marginTop + marginBottom;
					}
				}
			}
			//for absolutely positioned element, their bounds are set to their static position
			//but they do not influence the formatting of subsequent children or sibling
			else if (child.isPositioned() == false || child.isRelativePositioned() == true)
			{
				concatenatedY += child.bounds.height + marginTop + marginBottom;
			}

			//find widest line for shrink-to-fit algorithm
			if (childBounds.x + childBounds.width + computedStyle.marginRight > _formattingContextData.width)
			{
				//anonymous block box are not taken into account, as they always
				//have an auto width, they might cause error in the shrink-to-fit
				//computation, for instance if they take the width of the formatting
				//context root, it won't have the right max width
				if (child.isAnonymousBlockBox() == false)
				{
					_formattingContextData.width = childBounds.x + childBounds.width + computedStyle.marginRight;
				}
			}

			if (concatenatedY  > _formattingContextData.height)
			{
				_formattingContextData.height = concatenatedY;
			}
		}

		//the current ElementRenderer can either have an auto height
		//or have an explicit height
		if (elementRenderer.coreStyle.height == Dimension.cssAuto)
		{
			//when it has an auto height, it uses the height of its children
			childHeight = concatenatedY - childHeight;
			elementRenderer.bounds.height = childHeight + elementRendererComputedStyle.paddingBottom + elementRendererComputedStyle.paddingTop ;
			elementRendererComputedStyle.height = childHeight;
		}
		else
		{
			//here it has an explicit height, so it adds its own height
			//instead of the hieght of its children, if it children are
			//taller, they will overflow
			concatenatedY = childHeight;
			concatenatedY += elementRenderer.bounds.height;
		}

		concatenatedY += elementRendererComputedStyle.paddingBottom + parentCollapsedMarginBottom;

		_floatsManager.removeFloats(concatenatedY);

		return concatenatedY;

	}

	private function getCollapsedMarginTop(child:ElementRenderer, parentCollapsedMarginTop:Float):Float
	{
		var childComputedStyle:ComputedStyle = child.coreStyle.computedStyle;

		var marginTop:Float =childComputedStyle.marginTop;

		if (childComputedStyle.paddingTop == 0)
		{
			if (child.previousSibling != null)
			{
				var previousSibling:ElementRenderer = child.previousSibling;
				var previsousSiblingComputedStyle:ComputedStyle = previousSibling.coreStyle.computedStyle;
				if (previsousSiblingComputedStyle.paddingBottom == 0)
				{
					if (previsousSiblingComputedStyle.marginBottom > marginTop)
					{
						//this an exception for negative margin whose height are substracted
						//from collapsed margin height
						if (marginTop > 0)
						{
							marginTop = 0;
						}
					}
				}
			}
			else if (child.parentNode != null)
			{
				var parent:ElementRenderer = child.parentNode;

				if (parent.establishesNewFormattingContext() == false)
				{
					if (parent.coreStyle.computedStyle.paddingTop == 0)
					{
						if (parentCollapsedMarginTop > marginTop)
						{
							marginTop = 0;
						}
					}
				}
			}
		}

		return marginTop;
	}

	private function getCollapsedMarginBottom(child:ElementRenderer, parentCollapsedMarginBottom:Float):Float
	{
		var childComputedStyle:ComputedStyle = child.coreStyle.computedStyle;
		var marginBottom:Float = childComputedStyle.marginBottom;

		if (childComputedStyle.paddingBottom == 0)
		{
			if (child.nextSibling != null)
			{
				var nextSibling:ElementRenderer = child.nextSibling;
				var nextSiblingComputedStyle:ComputedStyle = nextSibling.coreStyle.computedStyle;
				if (nextSiblingComputedStyle.paddingTop == 0)
				{
					if (nextSiblingComputedStyle.marginTop > marginBottom)
					{
						marginBottom = 0;
					}
				}
			}
			else if (child.parentNode != null)
			{
				var parent:ElementRenderer = child.parentNode;

				if (parent.establishesNewFormattingContext() == false)
				{
					if (parent.coreStyle.computedStyle.paddingBottom == 0)
					{
						if (parentCollapsedMarginBottom > marginBottom)
						{
							marginBottom = 0;
						}
					}
				}
			}
		}

		return marginBottom;
	}

}