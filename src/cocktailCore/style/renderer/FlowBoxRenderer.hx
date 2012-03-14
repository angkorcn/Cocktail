/*
	This file is part of Cocktail http://www.silexlabs.org/groups/labs/cocktail/
	This project is © 2010-2011 Silex Labs and is released under the GPL License:
	This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License (GPL) as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version. 
	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	To read the license please visit http://www.gnu.org/copyleft/gpl.html
*/
package cocktailCore.style.renderer;

import cocktail.domElement.ContainerDOMElement;
import cocktail.domElement.DOMElement;
import cocktail.nativeElement.NativeElement;
import haxe.Log;

/**
 * Base class for ElementRenderer which are box
 * which can contain other ElementRenderer, such
 * as ElementRenderers generated by a ContainerDOMElement
 * 
 * Those elements can have children ElementRenderer, thus
 * forming the rendering tree
 * 
 * @author Yannick DOMINGUEZ
 */
class FlowBoxRenderer extends BoxRenderer
{
	/**
	 * A reference to all the children of this FolowBoxRenderer
	 */
	private var _children:Array<ElementRenderer>;
	public var children(getChildren, never):Array<ElementRenderer>;
	
	/**
	 * A reference to each line box generated by this FlowBoxRenderer
	 * and to each ElementRenderer in those line boxes.
	 * 
	 * LineBoxes are only generated by a FlowBoxRenderer if it
	 * establishes an inline formatting context
	 * 
	 * TODO : move it to BlockBoxRenderer, as InlineBoxRenderer can't
	 * have line boxes ?
	 */
	private var _lineBoxes:Array<Array<ElementRenderer>>;
	public var lineBoxes(getLineBoxes, never):Array<Array<ElementRenderer>>;
	
	/**
	 * class constructor
	 */
	public function new(domElement:DOMElement) 
	{
		super(domElement);
		_children = new Array<ElementRenderer>();
		_lineBoxes = new Array<Array<ElementRenderer>>();
	}
	
	/////////////////////////////////
	// PUBLIC METHODS
	////////////////////////////////
	
	/**
	 * add a children to the FlowBoxRenderer
	 * 
	 * TODO : first detach the child if it already has
	 * a parent
	 */
	public function addChild(elementRenderer:ElementRenderer):Void
	{
		_children.push(elementRenderer);
		elementRenderer.parent = this;
	}
	
	/**
	 * Remove a children of the FlowBoxRenderer
	 */
	public function removeChild(elementRenderer:ElementRenderer):Void
	{
		var newChildren:Array<ElementRenderer> = new Array<ElementRenderer>();
		
		for (i in 0..._children.length)
		{
			if (_children[i] != elementRenderer)
			{
				newChildren.push(_children[i]);
			}
		}
		_children = newChildren;
	}
	
	/**
	 * Add a line box to the FlowBoxRenderer
	 */
	public function addLineBox(lineBoxElements:Array<ElementRenderer>):Void
	{
		_lineBoxes.push(lineBoxElements);
	}
	
	/**
	 * Remove all the line boxes from the FlowBoxRenderer
	 */
	public function removeLineBoxes():Void
	{
		_lineBoxes = new Array<Array<ElementRenderer>>();
	}
	
	/////////////////////////////////
	// OVERRIDEN PUBLIC HELPER METHODS
	////////////////////////////////
	
	override public function establishesNewFormattingContext():Bool
	{
		return _domElement.style.establishesNewFormattingContext();
	}
	
	override public function isEmbedded():Bool
	{
		return false;
	}
	
	override public function canHaveChildren():Bool
	{
		return true;
	}
	
	/////////////////////////////////
	// SETTERS/GETTERS
	////////////////////////////////
	
	private function getChildren():Array<ElementRenderer>
	{
		return _children;
	}
	
	private function getLineBoxes():Array<Array<ElementRenderer>>
	{
		return _lineBoxes;
	}
	
	
}