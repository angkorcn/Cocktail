/*
	This file is part of Cocktail http://www.silexlabs.org/groups/labs/cocktail/
	This project is © 2010-2011 Silex Labs and is released under the GPL License:
	This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License (GPL) as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version. 
	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	To read the license please visit http://www.gnu.org/copyleft/gpl.html
*/
package cocktail.core.html;

import cocktail.core.renderer.TextInputRenderer;
import cocktail.core.style.CoreStyle;

/**
 * Form control.
 * 
 * @author Yannick DOMINGUEZ
 */
class HTMLInputElement extends EmbeddedElement
{

	/**
	 * the html tag name for a form input
	 */
	private static inline var HTML_INPUT_TAG_NAME:String = "input";
	
	/**
	 * the name of the value html attribute
	 */
	private static inline var HTML_VALUE_ATTRIBUTE:String = "value";
	
	/**
	 * The intrinsic width and ratio of a text input, 
	 * as they seem to be in Firefox on Windows
	 */
	private static inline var HTML_INPUT_TEXT_INTRINSIC_WIDTH:Int = 150;
	
	private static inline var HTML_INPUT_TEXT_INTRINSIC_RATIO:Float = 0.15;
	
	/**
	 * When the type attribute of the element has the value "text",
	 * "file" or "password", this represents the current contents
	 * of the corresponding form control, in an interactive user
	 * agent. Changing this attribute changes the contents of the
	 * form control, but does not change the value of the HTML
	 * value attribute of the element. When the type attribute
	 * of the element has the value "button", "hidden", "submit",
	 * "reset", "image", "checkbox" or "radio", this represents 
	 * the HTML value attribute of the element.
	 */
	public var value(get_value, set_value):String;
	
	/**
	 * class constructor
	 */
	public function new() 
	{
		super(HTML_INPUT_TAG_NAME);
	}
	
	//////////////////////////////////////////////////////////////////////////////////////////
	// OVERRIDEN PRIVATE RENDERING METHODS
	//////////////////////////////////////////////////////////////////////////////////////////
	
	/**
	 * Instantiate an input specific renderer
	 */
	override private function createElementRenderer():Void
	{
		_elementRenderer = new TextInputRenderer(this);
		_elementRenderer.coreStyle = _coreStyle;
	}
	
	/////////////////////////////////
	// OVERRIDEN SETTER/GETTER
	/////////////////////////////////
	
	override private function get_intrinsicWidth():Null<Int> 
	{
		return HTML_INPUT_TEXT_INTRINSIC_WIDTH;
	}
	
	override private function get_intrinsicRatio():Null<Float> 
	{
		return HTML_INPUT_TEXT_INTRINSIC_RATIO;
	}
	
	/////////////////////////////////
	// SETTER/GETTER
	/////////////////////////////////
	 
	private function set_value(value:String):String
	{
		setAttribute(HTML_VALUE_ATTRIBUTE, value);
		return value;
	}
	
	private function get_value():String
	{
		return getAttribute(HTML_VALUE_ATTRIBUTE);
	}
	
	
	
}