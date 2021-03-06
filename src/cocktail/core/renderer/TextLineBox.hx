/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/
package cocktail.core.renderer;

import cocktail.port.FontManager;
import cocktail.port.NativeElement;
import cocktail.core.geom.GeomData;
/**
 * A special kind of line box used to render text. A
 * TextRenderer will create as many text line box
 * as there is word/space in the text to render
 * 
 * @author Yannick DOMINGUEZ
 */
class TextLineBox extends LineBox
{
	/**
	 * The string of text rendered by this 
	 * text line box
	 */
	private var _text:String;
	
	/**
	 * class constructor
	 */
	public function new(elementRenderer:ElementRenderer, text:String) 
	{
		super(elementRenderer);
		
		_text = text;
		
		
		//create and store a native text element, using the styles of the 
		//TextRenderer which created this TextLineBox
		_nativeElement = new FontManager().createNativeTextElement(text, elementRenderer.coreStyle.computedStyle);
		
		#if (flash9 || nme)
		//get the dimensions of the text
		_bounds.width = getTextWidth();
		#end
		_bounds.height = getTextHeight();
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC RENDERING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Render the text using the graphic context as canvas.
	 * 
	 * TODO 4 : should also render text decoration, or should
	 * be on TextRenderer ?
	 */
	override public function render(graphicContext:NativeElement, forceRendering:Bool):Void
	{
		
		#if (flash9 || nme)
		_nativeElement.x = _bounds.x + _elementRenderer.globalContainingBlockOrigin.x;
		_nativeElement.y = _bounds.y + _elementRenderer.globalContainingBlockOrigin.y  + leadedAscent;
		var containerGraphicContext:flash.display.DisplayObjectContainer = cast(graphicContext);
		containerGraphicContext.addChild(_nativeElement);
		#end
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	override public function getBaselineOffset(parentBaselineOffset:Float, parentXHeight:Float):Float
	{
		return parentBaselineOffset;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PUBLIC HELPER METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Overriden as TextLineBox might be
	 * wrapping a space character
	 */
	override public function isSpace():Bool
	{
		return _text == " ";
	}
	
	/**
	 * Overriden as this is the text line box
	 */
	override public function isText():Bool
	{
		return true;
	}
	
	/**
	 * Overriden as a text line box is never
	 * considered absolutely positioned
	 */
	override public function isAbsolutelyPositioned():Bool
	{
		return false;
	}
	
	/**
	 * Overriden as a text line box never establishes
	 * a new formatting context
	 */
	override public function establishesNewFormattingContext():Bool
	{
		return false;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN GETTER/SETTER
	//////////////////////////////////////////////////////////////////////////////////////////

	
	/**
	 * Return the leaded ascent of the generated text
	 */
	override private function get_leadedAscent():Float 
	{
		var ascent:Float = _elementRenderer.coreStyle.fontMetrics.ascent;
		var descent:Float = _elementRenderer.coreStyle.fontMetrics.descent;	
	
		//the leading is an extra height to apply equally to the ascent
		//and the descent when laying out lines of text
		var leading:Float = _elementRenderer.coreStyle.computedStyle.lineHeight - (ascent + descent);

		//apply leading to the ascent and descent
		var leadedAscent:Float = ascent + leading / 2;
		var leadedDescent:Float = descent + leading / 2;
		
		return leadedAscent;
	}
	
	/**
	 * Return the leaded descent of the generated text
	 */
	override private function get_leadedDescent():Float 
	{
		var ascent:Float = _elementRenderer.coreStyle.fontMetrics.ascent;
		var descent:Float = _elementRenderer.coreStyle.fontMetrics.descent;	
	
		var leading:Float = _elementRenderer.coreStyle.computedStyle.lineHeight - (ascent + descent);

		var leadedAscent:Float = ascent + leading / 2;
		var leadedDescent:Float = descent + leading / 2;
		
		return leadedDescent;
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// PRIVATE METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * return the generated text width
	 */
	private function getTextWidth():Float
	{
		//here the text is a space character
		if (isSpace() == true)
		{
			//for a space, the width of a space is retrieved from the font metrics, plus the letter spacing
			//which also apply to space and the word spacing which aplies only to text
			return _elementRenderer.coreStyle.fontMetrics.spaceWidth + _elementRenderer.coreStyle.computedStyle.letterSpacing + _elementRenderer.coreStyle.computedStyle.wordSpacing;
		}
		//in this case the text is a word, the text width is returned, it already
		//contains the letter spacing which was applied when the text was rendered
		//by the flash text engine
		else
		{
			#if (flash9 || nme)
			return untyped _nativeElement.textWidth ;
			#else
			return 0.0;
			#end
		}	
	}

	/**
	 * return the generated text height, which is
	 * the addition of the leaded ascent and descent
	 * 
	 * TODO 4 : should be line height in some cases
	 */
	private function getTextHeight():Float
	{
		return leadedAscent + leadedDescent;
	}
	
	
}