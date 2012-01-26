/*
	This file is part of Cocktail http://www.silexlabs.org/groups/labs/cocktail/
	This project is © 2010-2011 Silex Labs and is released under the GPL License:
	This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License (GPL) as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version. 
	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	To read the license please visit http://www.gnu.org/copyleft/gpl.html
*/
package cocktailCore.domElement.js;

import cocktailCore.domElement.abstract.AbstractBodyDOMElement;
import cocktailCore.keyboard.Keyboard;
import js.Lib;

/**
 * This is the JavaScript implementation of the BodyDOMElement
 * 
 * @author Yannick DOMINGUEZ
 */
class BodyDOMElement extends AbstractBodyDOMElement
{
	/**
	 * class constructor
	 */
	public function new() 
	{
		super();
	}
	
	/**
	 * In Js, keyboard must be listened to on the "document"
	 * object instead of the "body" object
	 */
	override private function initKeyboard():Void
	{
		_keyboard = new Keyboard(Lib.document);
	}
	
}