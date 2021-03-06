/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/
package cocktail.core.style.computer;

import cocktail.core.style.CoreStyle;
import cocktail.core.style.StyleData;
import cocktail.core.unit.UnitManager;
import cocktail.core.geom.GeomData;
import cocktail.core.unit.UnitData;
import haxe.Log;
import cocktail.core.font.FontData;

/**
 * This class computes all the background styles.
 * 
 * It is assumed that all the styles, except for 
 * background-color are represented by an array
 * of the same length as the background-image style,
 * otherwise, illegal range exception are thrown.
 * 
 * The background computation is done in 2 phases : 
 * - first all the styles that can be immediately
 * computed after a layout (such as background-color)
 * are computed
 * - then, at rendering time when each of the background
 * box (the boxes onto which a background is drawn,
 * for instance for an inline HTMLElement displayed on multiple
 * lines, there will be one background box for each line) and
 * each of the background image dimensions are known, all
 * the styles are computed
 * 
 * @author Yannick DOMINGUEZ
 */
class BackgroundStylesComputer 
{
	/**
	 * Class contructor. Private, as
	 * this class is meant to be accessed
	 * through its public static methods
	 */
	private function new() 
	{
		
	}

	//////////////////////////////////////////////////////////////////////////////////////////
	// PUBLIC STATIC METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Compute the background styles which can be computed 
	 * when the layout is done. the background boxes and
	 * the dimensions of the background images are not yet
	 * known
	 */
	public static function compute(style:CoreStyle):Void
	{
		//actually compute the background color
		style.computedStyle.backgroundColor = getComputedBackgroundColor(style);
	}
	
	/**
	 * This method is called during rendering for each background image of a HTMLElement
	 * for each background boxes
	 * 
	 * At this point, all the background boxes of the HTMLElement are known and also
	 * the intrinsic dimension of the background-image which can be an externally loaded
	 * bitmap or a programatically drawn gradient. The dimension of the background
	 * image is used to compute some styles.
	 * 
	 * @param	style
	 * @param	backgroundBox
	 * @param	intrinsicWidth
	 * @param	intrinsicHeight
	 * @param	intrinsicRatio
	 * @param	backgroundPosition
	 * @param	backgroundSize
	 * @param	backgroundOrigin
	 * @param	backgroundClip
	 * @param	backgroundRepeat
	 * @param	backgroundImage
	 * @return	a structure containing each of the computed background styles for the
	 * current background-image
	 */
	public static function computeIndividualBackground(style:CoreStyle, backgroundBox:RectangleData,
	intrinsicWidth:Null<Int>, intrinsicHeight:Null<Int>, intrinsicRatio:Null<Float>, 
	backgroundPosition:BackgroundPosition,
	backgroundSize:BackgroundSize,
	backgroundOrigin:BackgroundOrigin,
	backgroundClip:BackgroundClip,
	backgroundRepeat:BackgroundRepeat,
	backgroundImage:BackgroundImage):ComputedBackgroundStyleData
	{
		var fontMetrics:FontMetricsData = style.fontMetrics;
		
		//get the area onto which the background image is positioned
		var backgroundPositioningArea:RectangleData = getBackgroundPositioningArea(style, backgroundOrigin, backgroundBox);
		
		//get the absolute dimensions of the background image
		var computedBackgroundSize:DimensionData = getComputedBackgroundSize(backgroundSize, backgroundPositioningArea,
		intrinsicWidth, intrinsicHeight, intrinsicRatio, fontMetrics.fontSize, fontMetrics.xHeight);
		
		//get the offset of the background image relative to the background box top left corner
		var computedBackgroundPosition:PointData = getComputedBackgroundPosition(backgroundPosition,
		backgroundPositioningArea, computedBackgroundSize, fontMetrics.fontSize, fontMetrics.xHeight);
		
		//get the clipping area (the area where the background image is actually displayed)
		var computedBackgroundClip:RectangleData = getBackgroundPaintingArea(style, backgroundClip, backgroundBox);
		
		var computedBackgroundStyle:ComputedBackgroundStyleData = {
			backgroundOrigin:backgroundPositioningArea,
			backgroundClip:computedBackgroundClip,
			backgroundRepeat:backgroundRepeat,
			backgroundImage:backgroundImage,
			backgroundSize:computedBackgroundSize,
			backgroundPosition:computedBackgroundPosition
		}
		
		return computedBackgroundStyle;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE STATIC METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
		// BACKGROUND COLOR
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Return the background color as an integer
	 */
	private static function getComputedBackgroundColor(style:CoreStyle):ColorData
	{
		var computedColor:ColorData;
		computedColor = UnitManager.getColorDataFromCSSColor(style.backgroundColor);
		
		return computedColor;
	}
	
		// BACKGROUND POSITION
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Compute the background position of the background image 
	 * (the offset from the top left corner of the background box)
	 * 
	 * @param	backgroundPosition
	 * @param	backgroundPositioningArea
	 * @param	computedBackgroundSize
	 * @param	emReference
	 * @param	exReference
	 * @return
	 */
	private static function getComputedBackgroundPosition(backgroundPosition:BackgroundPosition, backgroundPositioningArea:RectangleData, computedBackgroundSize:DimensionData, emReference:Float, exReference:Float):PointData
	{
		var computedBackgroundXPosition:Float = getComputedBackgroundXPosition(backgroundPosition.x, backgroundPositioningArea.width, computedBackgroundSize.width,  emReference, exReference);
		var computedBackgroundYPosition:Float = getComputedBackgroundYPosition(backgroundPosition.y, backgroundPositioningArea.height, computedBackgroundSize.height, emReference, exReference);
		
		var computedBackgroundPosition:PointData = {
			x:computedBackgroundXPosition,
			y:computedBackgroundYPosition
		};
		
		return computedBackgroundPosition;
	}
	
	/**
	 * Return the x offset of the background image
	 */
	private static function getComputedBackgroundXPosition(backgroundPosition:BackgroundPositionX, backgroundPositioningAreaDimension:Float, imageDimension:Float, emReference:Float, exReference:Float):Float
	{
		var computedBackgroundXPosition:Float;
		
		switch (backgroundPosition)
		{
			case BackgroundPositionX.length(value):
				computedBackgroundXPosition = UnitManager.getPixelFromLength(value, emReference, exReference);
			
			//for percent value, it is relative to the background positioning area minus the width of the 
			//background image, such as a 100% will have the right side of the picture touch the right side
			//of the background positioning area
			case BackgroundPositionX.percent(value):
				computedBackgroundXPosition = UnitManager.getPixelFromPercent(value, backgroundPositioningAreaDimension - imageDimension);
			
			//same as 50%	
			case BackgroundPositionX.center:
				computedBackgroundXPosition = UnitManager.getPixelFromPercent(50, backgroundPositioningAreaDimension - imageDimension);
			
			//same as 0%	
			case BackgroundPositionX.left:
				computedBackgroundXPosition = UnitManager.getPixelFromPercent(0, backgroundPositioningAreaDimension - imageDimension);
			
			//same as 100%	
			case BackgroundPositionX.right:
				computedBackgroundXPosition = UnitManager.getPixelFromPercent(100, backgroundPositioningAreaDimension - imageDimension);
		}
		
		return computedBackgroundXPosition;
	}
	
	/**
	 * Return the y offset of the background image. Same as getComputedBackgroundXPosition
	 */
	private static function getComputedBackgroundYPosition(backgroundPosition:BackgroundPositionY, backgroundPositioningAreaDimension:Float, imageDimension:Float, emReference:Float, exReference:Float):Float
	{
		var computedBackgroundYPosition:Float;
		
		switch (backgroundPosition)
		{
			case BackgroundPositionY.length(value):
				computedBackgroundYPosition = UnitManager.getPixelFromLength(value, emReference, exReference);
				
			case BackgroundPositionY.percent(value):
				computedBackgroundYPosition = UnitManager.getPixelFromPercent(value, backgroundPositioningAreaDimension - imageDimension);
				
			case BackgroundPositionY.center:
				computedBackgroundYPosition = UnitManager.getPixelFromPercent(50, backgroundPositioningAreaDimension - imageDimension);
				
			case BackgroundPositionY.top:
				computedBackgroundYPosition = UnitManager.getPixelFromPercent(0, backgroundPositioningAreaDimension - imageDimension);
				
			case BackgroundPositionY.bottom:
				computedBackgroundYPosition = UnitManager.getPixelFromPercent(100, backgroundPositioningAreaDimension - imageDimension);
		}
		
		return computedBackgroundYPosition;
	}
	
			// BACKGROUND SIZE
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * 
	 * Compute the actual dimension that the 
	 * background image should have
	 * 
	 * @param	backgroundSize
	 * @param	backgroundPositioningArea
	 * @param	intrinsicWidth
	 * @param	intrinsicHeight
	 * @param	intrinsicRatio
	 * @param	emReference
	 * @param	exReference
	 * @return
	 */
	private static function getComputedBackgroundSize(backgroundSize:BackgroundSize, backgroundPositioningArea:RectangleData, intrinsicWidth:Null<Int>, intrinsicHeight:Null<Int>, intrinsicRatio:Null<Float>, emReference:Float, exReference:Float):DimensionData
	{
		var computedBackgroundSize:DimensionData;
		
		switch (backgroundSize)
		{
			//Scale the image, while preserving its
			//intrinsic aspect ratio (if any), to the largest size such that 
			//both its width and its height can fit inside the background positioning area.
			case BackgroundSize.contain:
				if (intrinsicRatio != null)
				{
					var ratio:Float = intrinsicRatio / (backgroundPositioningArea.width / backgroundPositioningArea.height);
					
					computedBackgroundSize = {
						width:intrinsicWidth * ratio,
						height:intrinsicHeight * ratio
					}
				}
				else
				{
					computedBackgroundSize = {
						width:backgroundPositioningArea.width,
						height:backgroundPositioningArea.height
					}
				}
				
			//Scale the image, while preserving its intrinsic aspect
			//ratio (if any), to the smallest size such that both its width
			//and its height can completely cover the background positioning area. 	
			case BackgroundSize.cover:
				if (intrinsicRatio != null)
				{
					var ratio:Float =  (backgroundPositioningArea.width / backgroundPositioningArea.height) / intrinsicRatio;
					
					computedBackgroundSize = {
						width:intrinsicWidth * ratio,
						height:intrinsicHeight * ratio
					}
				}
				else
				{
					computedBackgroundSize = {
						width:backgroundPositioningArea.width,
						height:backgroundPositioningArea.height
					}
				}	
			
				
			case BackgroundSize.dimensions(value):
				computedBackgroundSize = {
					width:getBackgroundSizeStyleDimensionData(value.x, value.y, backgroundPositioningArea.width, backgroundPositioningArea.height,
					intrinsicWidth, intrinsicHeight, intrinsicRatio, emReference, exReference),
					height:getBackgroundSizeStyleDimensionData(value.y, value.x, backgroundPositioningArea.height, backgroundPositioningArea.width,
					intrinsicHeight, intrinsicWidth, intrinsicRatio, emReference, exReference)
				}
		}
		
		return computedBackgroundSize;
	}
	
	/**
	 * Return the width or height of the background image, sized with 
	 * a length, percentage or auto value
	 * 
	 * @param	value
	 * @param	opositeBackgroundSizeValue
	 * @param	backgroundPositioningAreaDimension
	 * @param	intrinsicDimension
	 * @param	opositeIntrinsicDimension
	 * @param	intrinsicRatio
	 * @param	emReference
	 * @param	exReference
	 * @return
	 */
	private static function getBackgroundSizeStyleDimensionData(value:BackgroundSizeDimension, opositeBackgroundSizeValue:BackgroundSizeDimension,
	backgroundPositioningAreaDimension:Float, opositeBackgroundAreaDimension:Float, intrinsicDimension:Null<Int>, opositeIntrinsicDimension:Null<Int>, intrinsicRatio:Null<Float>,
	emReference:Float, exReference:Float):Float
	{
		var backgroundSizeStyleDimension:Float;
		
		switch (value)
		{
			//absolute or relative length value
			case BackgroundSizeDimension.length(value):
				backgroundSizeStyleDimension = UnitManager.getPixelFromLength(value, emReference, exReference);
			
			//percent relative to the background positioning area	
			case BackgroundSizeDimension.percent(value):
				backgroundSizeStyleDimension = UnitManager.getPixelFromPercent(value, backgroundPositioningAreaDimension);
			
			//for auto, use intrinsic dimension if any or else,
			//treated as a 100% value
			case BackgroundSizeDimension.cssAuto:
				//if the other dimension is alos auto, use the intrinsic dimension if any
				if (intrinsicDimension != null && opositeBackgroundSizeValue == BackgroundSizeDimension.cssAuto)
				{
					backgroundSizeStyleDimension = intrinsicDimension;
				}
				//if the other dimension is not auto, compute it and use a ratio of its dimension
				//to keep the proportion of the background image
				else if (opositeIntrinsicDimension != null && intrinsicRatio != null)
				{
					var opositeDimension:Float = getBackgroundSizeStyleDimensionData(opositeBackgroundSizeValue, value,
					opositeBackgroundAreaDimension, backgroundPositioningAreaDimension, opositeIntrinsicDimension, intrinsicDimension,
					intrinsicRatio, emReference, exReference);
					
					backgroundSizeStyleDimension = opositeDimension * intrinsicRatio;
				}
				//if the background image doesn't have intrinsic dimensions, treat it like 100%
				else
				{
					backgroundSizeStyleDimension = UnitManager.getPixelFromPercent(100, backgroundPositioningAreaDimension);
				}
		}
		
		return backgroundSizeStyleDimension;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE UTILS STATIC METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Return the rectangle of the positioning area, the area whose top left
	 * corner will be used as origin for the background image. 
	 * This area can be sized to the border, padding or content box
	 * of the background box
	 * 
	 * The positioning area is defined in the space of the margin box of the HTMLElement
	 * 
	 * @param	style
	 * @param	backgroundOrigin
	 * @return
	 */
	private static function getBackgroundPositioningArea(style:CoreStyle, backgroundOrigin:BackgroundOrigin, backgroundBox:RectangleData):RectangleData
	{
		var backgroundPositioningArea:RectangleData;
		
		var height:Float;
		var width:Float;
		var x:Float;
		var y:Float;
		
		switch (backgroundOrigin)
		{
			case BackgroundOrigin.borderBox:
				height = backgroundBox.height;
				width = backgroundBox.width;
				x = 0.0;
				y = 0.0;
				
				
			case BackgroundOrigin.paddingBox:
				height = backgroundBox.height;
				width = backgroundBox.width;
				x = 0.0;
				y = 0.0;
				
				
			case BackgroundOrigin.contentBox:
				height = backgroundBox.height - style.computedStyle.marginTop - style.computedStyle.marginBottom - style.computedStyle.paddingTop - style.computedStyle.paddingBottom;
				width = backgroundBox.width - style.computedStyle.marginLeft - style.computedStyle.marginRight - style.computedStyle.paddingLeft - style.computedStyle.paddingRight;
				x = 0.0;
				y = 0.0 ;
				
		}
		
		backgroundPositioningArea = {
			height:height,
			width:width,
			x:x,
			y:y
		}
		
		return backgroundPositioningArea;
	}
	
	/**
	 * Return the rectangle of the painting area, the area where
	 * the background image will be actually displayed, all the pixels
	 * overflowing are clipped. It can be smaller than the background
	 * positioning area.
	 * 
	 * The painting area is defined in the space of the margin box
	 * of the HTMLElement,like the positioning area
	 * 
	 * @param	style
	 * @param	backgroundClip
	 * @param	backgroundBox
	 * @return
	 */
	private static function getBackgroundPaintingArea(style:CoreStyle, backgroundClip:BackgroundClip, backgroundBox:RectangleData):RectangleData
	{
		var backgroundPaintingArea:RectangleData;
		
		var height:Float;
		var width:Float;
		var x:Float;
		var y:Float;
		
		switch (backgroundClip)
		{
			case BackgroundClip.borderBox:
				height = backgroundBox.height;
				width = backgroundBox.width;
				x = 0.0;
				y = 0.0;
				
			case BackgroundClip.paddingBox:
				height = backgroundBox.height;
				width = backgroundBox.width;
				x = style.computedStyle.marginLeft;
				y = style.computedStyle.marginTop;
				
				
			case BackgroundClip.contentBox:
				height = backgroundBox.height - style.computedStyle.marginTop - style.computedStyle.marginBottom - style.computedStyle.paddingTop - style.computedStyle.paddingBottom;
				width = backgroundBox.width - style.computedStyle.marginLeft - style.computedStyle.marginRight - style.computedStyle.paddingLeft - style.computedStyle.paddingRight;
				x = style.computedStyle.marginLeft + style.computedStyle.paddingLeft;
				y = style.computedStyle.marginTop + style.computedStyle.paddingTop;
				
		}
		
		backgroundPaintingArea = {
			height:height,
			width:width,
			x:x,
			y:y
		}
		
		return backgroundPaintingArea;
	}
}