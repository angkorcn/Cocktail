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
import cocktail.core.html.EmbeddedElement;
import cocktail.core.html.HTMLConstants;
import cocktail.core.html.HTMLElement;
import cocktail.core.html.HTMLImageElement;
import cocktail.core.html.HTMLObjectElement;
import cocktail.core.resource.ImageLoader;
import cocktail.core.resource.ResourceManager;
import cocktail.port.Resource;
import cocktail.port.NativeElement;
import cocktail.core.geom.GeomData;

/**
 * An ElementRenderer displaying an object (plugin)
 * to the screen
 * 
 * @author Yannick DOMINGUEZ
 */
class ObjectRenderer extends EmbeddedBoxRenderer
{
	private static inline var NO_SCALE:String = "noscale";
	
	private static inline var SHOW_ALL:String = "showall";
	
	private static inline var EXACT_FIT:String = "exactfit";
	
	/**
	 * class constructor
	 */
	public function new(node:HTMLElement) 
	{
		super(node);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PRIVATE RENDERING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////

	/**
	 * When rendered, attach the plugin object to the native display list
	 */
	override private function renderEmbeddedAsset(graphicContext:NativeElement):Void
	{
		#if (flash9 || nme)
		var containerGraphicContext:flash.display.DisplayObjectContainer = cast(graphicContext);
	
		var htmlObjectElement:HTMLObjectElement = cast(node);
		var asset:flash.display.Loader = cast(htmlObjectElement.embeddedAsset);
		
		var globalBounds:RectangleData = globalBounds;
		asset.transform.matrix = new flash.geom.Matrix();
		
		var width:Float = 0.0;
		var height:Float = 0.0;
		
		//get the intrinsic width and height of the sprite
		try {
			width = asset.contentLoaderInfo.width;
			height = asset.contentLoaderInfo.height;
		}
		catch (e:Dynamic)
		{
			
		}
		
		var scaleMode:String = getScaleMode();
		
		var assetBounds:RectangleData = getAssetBounds(_coreStyle.computedStyle.width, _coreStyle.computedStyle.height,
		width, height);

		
		switch (scaleMode)
		{
			case NO_SCALE:
				asset.x = globalBounds.x + _coreStyle.computedStyle.paddingLeft;
				asset.y = globalBounds.y + _coreStyle.computedStyle.paddingTop;
				
			case EXACT_FIT:
				asset.x = globalBounds.x + _coreStyle.computedStyle.paddingLeft;
				asset.y = globalBounds.y + _coreStyle.computedStyle.paddingTop;
				asset.scaleX = _coreStyle.computedStyle.width / width;
				asset.scaleY = _coreStyle.computedStyle.height / height;

			default:
				asset.x = globalBounds.x + _coreStyle.computedStyle.paddingLeft + assetBounds.x;
				asset.y = globalBounds.y + _coreStyle.computedStyle.paddingTop + assetBounds.y;
				asset.scaleX = assetBounds.width / width;
				asset.scaleY = assetBounds.height / height;
		}
		
		//mask the sprite so that it doesn't overflow
		var mask = new flash.display.Sprite();
		mask.graphics.beginFill(0xFF0000, 0.0);
		mask.graphics.drawRect( 
		globalBounds.x + _coreStyle.computedStyle.paddingLeft, globalBounds.y + _coreStyle.computedStyle.paddingTop,
		_coreStyle.computedStyle.width, _coreStyle.computedStyle.height);
		mask.graphics.endFill();
		asset.mask = mask;
		
		containerGraphicContext.addChild(asset);
		
		#end
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE UTILS METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	private function getScaleMode():String
	{
		var scaleMode:String = SHOW_ALL;
		for (i in 0...node.childNodes.length)
		{
			var child:HTMLElement = node.childNodes[i];
			
			if (child.tagName == HTMLConstants.HTML_PARAM_TAG_NAME)
			{
				if (child.getAttribute(HTMLConstants.HTML_NAME_ATTRIBUTE_NAME) != null)
				{
					if (child.getAttribute(HTMLConstants.HTML_NAME_ATTRIBUTE_NAME) == "scale")
					{
						if (child.getAttribute(HTMLConstants.HTML_VALUE_ATTRIBUTE_NAME) != null)
						{
							scaleMode = child.getAttribute(HTMLConstants.HTML_VALUE_ATTRIBUTE_NAME);
						}
					}
				}
			}
		}
		
		return scaleMode;
	}
	
	/**
	 * Utils method returning the right rectangle so that
	 * the video or poster frame can take the maximum available width
	 * and height while preserving their aspect ratio and also be 
	 * centered in the available space
	 * 
	 * @param	availableWidth the maximum width available for the poster frame or video
	 * @param	availableHeight the maximum height available for the poster frame or video
	 * @param	assetWidth the intrinsic width of the video or poster frame
	 * @param	assetHeight the intrinsic height of the video or poster frame
	 * @return	the bounds of the asset
	 */
	private function getAssetBounds(availableWidth:Float, availableHeight:Float, assetWidth:Float, assetHeight:Float):RectangleData
	{
		//those will hold the actual value used for the video or poster 
		//dimensions, with the kept aspect ratio
		var width:Float;
		var height:Float;

		if (availableWidth > availableHeight)
		{
			//get the ratio between the intrinsic asset width and the width it must be displayed at
			var ratio:Float = assetHeight / availableHeight;
			
			//check that the asset isn't wider than the available width
			if ((assetWidth / ratio) < availableWidth)
			{
				//the asset width use the computed width while the height apply the ratio
				//to the asset height, so that the ratio is kept while displaying the asset
				//as big as possible
				width =  assetWidth / ratio ;
				height = availableHeight;
			}
			//else reduce the height instead of the width
			else
			{
				ratio = assetWidth / availableWidth;
				
				width = availableWidth;
				height = assetHeight / ratio;
			}
		}
		//same as above but inverted
		else
		{
			var ratio:Float = assetWidth / availableWidth;
			
			if ((assetHeight / ratio) < availableHeight)
			{
				height = assetHeight / ratio;
				width = availableWidth;
			}
			else
			{
				ratio = assetHeight / availableHeight;
				width =  assetWidth / ratio ;
				height = availableHeight;
			}
		}
		
		//the asset must be centered in the ElementRenderer, so deduce the offsets
		//to apply to the x and y direction
		var xOffset:Float = (availableWidth - width) / 2;
		var yOffset:Float = (availableHeight - height) / 2;
		
		return {
			width:width,
			height:height,
			x:xOffset,
			y:yOffset
		}
	}
	
}