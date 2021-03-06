/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/

package ;
import js.Lib;

/**
 * TODO : fail height of absolute container is wrong
 */
class Test 
{
	public static function main()
	{	
		new Test();
	}
	
	public function new()
	{
		//should add black border
		var test = '<div>';
		test += '<div style="position:absolute; background-color:orange;  margin:50px;">';
		test += '<div style="height:1in; background-color:green; width:1in; margin:50px;">';
		test += '<div style="background-color:blue; height:1in; width:1in; position:absolute; right:0; top:0;"></div>';
		test += '</div></div></div>';
		
		Lib.document.body.innerHTML = test;
	}
}