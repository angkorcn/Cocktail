/*
 * Cocktail, HTML rendering engine
 * http://haxe.org/com/libs/cocktail
 *
 * Copyright (c) Silex Labs
 * Cocktail is available under the MIT license
 * http://www.silexlabs.org/labs/cocktail-licensing/
*/
package org.intermedia.view;

import haxe.Firebug;
import js.Lib;
import js.Dom;
import org.intermedia.model.ApplicationModel;
import haxe.Timer;
import org.intermedia.Settings;

/**
 * Base class for list views. Inherithed by the 3 ListViews.
 * 
 * @author Raphael Harmel
 */

class ListViewBase extends ViewBase
{

	// style
	private var _style:ListStyleModel;
	
	//Called when an item is selected.
	public var onListItemSelected:CellData->Void;
	
	// called when the list is requesting more data to be loaded
	public var onDataRequest:String->Void;
	
	// display list end loader
	public var displayListBottomLoader:Bool;
	
	//Hold a ref to each created cells
	private var _cells:Array<CellBase>;
	
	// the list id feed, used to store the feedUrl
	public var id:String;
	
	// list bottom loader image container
	private var _listBottomLoader:HtmlDom;

	// list bottom loader image
	private var _bottomLoaderImage:Image;
	
	// data requested flag. used to make sure only one data request happens when reaching the bottom of the list
	private var _dataRequested:Bool;
	
	// Used to resolve a mobile safari bug
	// _scrollTop is used to store previous scrollTop value and set it back after new data has been added to the DOM
	//private var _scrollTop:Int;

	public function new()
	{
		super();
		
		// init style
		initStyle();
		
		// apply style
		_style.list(node);
		
		// init _dataRequested flag
		_dataRequested = false;
		
		displayListBottomLoader = true;
		_cells = new Array<CellBase>();
		
		buildBottomLoader();
		
		node.onscroll = onScrollCallback;
		
	}
	
	/**
	 * initialize the default style
	 */
	private function initStyle():Void
	{
		// init style model
		_style = {
			list:ListViewStyle.setListStyle
		}
	}
	
	/**
	 * Bottom loader builder
	 */
	private function buildBottomLoader():Void
	{
		_bottomLoaderImage = cast Lib.document.createElement("img");
		ListViewStyle.loaderImage(_bottomLoaderImage);
		_bottomLoaderImage.src = "assets/loading.gif";
		_listBottomLoader = Lib.document.createElement("div");
		_listBottomLoader.appendChild(_bottomLoaderImage);
		CellStyle.setCellStyle(_listBottomLoader);
	}
	
	
	/**
	 * update view
	 */
	override private function updateView():Void
	{
		for (index in Reflect.fields(_data))
		{
			// build cell
			var cell:CellBase = createCell();
			
			// set cell data
			cell.data = Reflect.field(_data, index);
			
			// set mouseUp callback
			cell.node.onmouseup = function(mouseEventData:Event) { onListItemSelectedCallback(cell.data); };
			
			// push created cell to _cells
			_cells.push(cell);

			// add cell to list
			node.appendChild(cell.node);
		}
		
		// if loader is attached to to list container, detach it
		if (_listBottomLoader.parentNode != null)
		{
			node.removeChild(_listBottomLoader);
		}
		// add loader at the bottom of the screen if there is still data to load
		if(displayListBottomLoader == true)
		{
			node.appendChild(_listBottomLoader);
		}
		
		// if list is attached to body
		if(node.parentNode.parentNode != null)
		{
			// if list content height is not filling the totality of the screen's height
			// removed as now list update is done without beeing attached, and as a result scrollHeight equals 0
			/*Firebug.trace("node.scrollHeight: " + node.scrollHeight);
			if (node.scrollHeight <= (Lib.window.innerHeight - Constants.LIST_TOP) + Constants.LIST_BOTTOM_LOADER_VERTICAL_MARGIN)
			{
				// request more data
				onDataRequestCallback(id);
			}*/
		}
		
		// reset _dataRequested flag
		_dataRequested = false;
		
	}
	
	/**
	 * Creates a cell of the correct type
	 * To be overriden in child classes
	 * 
	 * @return
	 */
	private function createCell():CellBase
	{
		var cell:CellBase = new CellBase();
		return cell;
	}
	
	/**
	 * onListItemSelected callback
	 * @param	cellData
	 */
	public function onListItemSelectedCallback(cellData:CellData)
	{
		if (onListItemSelected != null)
		{
			onListItemSelected(cellData);
		}
	}
	
	/**
	 * list scroll callback
	 * @param	event
	 */
	private function onScrollCallback(event:Event):Void
	{
		// if the bottom of the loading screen is reached via scrolling
		if (!_dataRequested && (node.scrollTop >= node.scrollHeight - (Lib.window.innerHeight - Constants.LIST_TOP) - Constants.LIST_BOTTOM_LOADER_VERTICAL_MARGIN) )
		{
			// set _dataRequested flag
			_dataRequested = true;
			
			// if using online data
			if(Settings.ONLINE)
			{
				// call callback
				onDataRequestCallback(id);
			}
			// if using local data
			else
			{
				// instead of calling onDataRequestCallback(id), we reload the same data again (way faster as no xml parsing !)
				data = _data;
			}
		}
	}
	
	/**
	 * load more data request callback
	 * @param	event
	 */
	private function onDataRequestCallback(id:String):Void
	{
		// call callback
		if (onDataRequest != null)
		{
			// if list has not already requested new data, request new data
			onDataRequest(id);
		}
	}
	
	/** 
	 * Refresh list styles
	 */
	public function refreshStyles():Void
	{
		// apply style
		_style.list(node);
		
		// refresh cells
		for (cell in _cells)
		{
			cell.refreshStyles();
		}
	}

}

typedef ListStyleModel =
{
	var list:HtmlDom->Void;
}