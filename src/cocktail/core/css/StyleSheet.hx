package cocktail.core.css;

import cocktail.core.dom.Node;
/**
 * ...
 * @author Yannick DOMINGUEZ
 */

class StyleSheet 
{

	public var type(default, null):String;
	
	public var href(default, null):String;
	
	public var ownerNode(default, null):Node;
	
	public var parentStyleSheet(default, null):StyleSheet;
	
	//public var media(default, null):MediaList;
	
	public var disabled:Bool;
	
	public function new() 
	{
		
	}
	
}