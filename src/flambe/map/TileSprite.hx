package flambe.map;

import flambe.display.Graphics;
import flambe.display.Sprite;
import flambe.math.FMath;
import flambe.math.Matrix;
import flambe.math.Point;
import flambe.math.Rectangle;
import flambe.util.Arrays;
import flambe.util.Assert;
import flambe.map.TileSymbol;

/**
 * A sprite which renders a tilemap and can be used by various tile engines, or used standalone.
 * @author Kipp Ashford
 * 
 * A few functions dealing with 2d flattened arrays adapted from the polygonal Array2 class.
 * Michael Baczynski, http://www.polygonal.de
 * https://github.com/polygonal/ds/blob/master/src/de/polygonal/ds/Array2.hx
 * 
 */
class TileSprite extends Sprite
{
	/** The symbols used to render the layer. Each index in the array corresponds to the id of the symbol to be rendered. */
	public var symbols (default, null) :Array<TileSymbol>;
	/** The width of each tile. */
	public var tileWidth (default, null) :Int;
	/** The height of each tile. */
	public var tileHeight (default, null) :Int;
	/** The number of tiles along the x axis. */
	public var columns (default, null) :Int;
	/** The number of tiles along the y axis. */
	public var rows (default, null) :Int;

	/**
	 * The region of the map to draw in pixel values. If null, will render the entire map every drawing update. 
	 * This does not automatically change the x, y of the TileSprite.
	 */
	public var region :Rectangle;

	/** The flattened 2D array of tiles to render */
	private var _tiles :Array<Int>;

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Renders a tile layer.
	 */
	public function new(symbols :Array<TileSymbol>, tileWidth :Int, tileHeight :Int)
	{
		super();
		this.symbols = symbols;
		this.tileWidth = tileWidth;
		this.tileHeight = tileHeight;	
		_tiles = [];
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Replaces the map information with info from a flattened 2D array.
	 * 
	 * @param  tiles   :Array<Int>   The array of tile ids.
	 * @param  columns :Int          The width of the map (in tiles)
	 * @param  rows    :Int          The height of the map (in tiles)
	 */
	public function fromArray(tiles :Array<Int>, columns :Int, rows :Int) :TileSprite
	{
		Assert.that(columns * rows == tiles.length, "The number of tiles must match with the columns and rows information.", [columns, rows]);
		_tiles = tiles;
		this.columns = columns;
		this.rows = rows;
		return this;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Resizes the layer. This is potentially a slow operation.
	 * (Thanks polygonal)
	 * 
	 * @param  columns  The new number of columns.
	 * @param  rows     The new amount of rows.
	 * @return        [description]
	 */
	public function resize(columns :Int, rows :Int)
	{
		#if debug
		Assert.that(columns >= 2 && rows >= 2, "invalid size ", [columns, rows]);
		#end

		if (columns == this.columns && rows == this.rows) return;
		var t = _tiles;
		_tiles = Arrays.create(columns * rows);
		var ii :Int = _tiles.length;
		while (ii-->0) {
			_tiles[ii] = 0; // Make sure to never contain null values.
		}

		var minX = columns < this.columns ? columns : this.columns;
		var minY = rows < this.rows ? rows : this.rows;

		for (y in 0...minY)
		{
			var t1 = y * columns;
			var t2 = y * this.columns;
			for (x in 0...minX) {
				_tiles[t1 + x] = t[t2 + x];
			}
		}

		this.columns = columns;
		this.rows = rows;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Appends a row of tiles to the TileSprite.
	 * 
	 * @param  row :Array<Int>   [description]
	 * @return     [description]
	 */
	public function appendRow(row :Array<Int>)
	{
		#if debug
		Assert.that(row != null, "row is null");
		Assert.that(row.length >= columns, "insufficient row values");
		#end

		var t = columns * rows++;
		
		for (i in 0...columns) {
			_tiles[t + i] = row[i];
			// __set(t + i, row[i]);
		}
	}

	/* ---------------------------------------------------------------------------------------- */

	/**
	 * Appends a column of tiles to the TileSprite
	 * 
	 * @param  column :Array<Int>   [description]
	 * @return        [description]
	 */
	public function appendColumn(column :Array<Int>)
	{
		#if debug
		Assert.that(column != null, "column is null");
		Assert.that(column.length >= rows, "insufficient column values");
		#end

		var t = rows * columns;
		var l = t + rows;
		var i = rows - 1;
		var j = rows;
		var x = columns;
		var y = l;

		while (y-->0)
		{
			if (++x > columns) {
				x = 0;
				j--;
				_tiles[y] = column[i--];
			} else {
				_tiles[y] = _tiles[y - j];
			}
		}

		columns++;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Sets a tile at a given coordinate.
	 * 
	 * @param column :Int [description]
	 * @param row    :Int [description]
	 * @param id     :Int The ID of the symbol.
	 */
	public inline function setTile(column :Int, row :Int, id :Int)
	{
		// Sets a tile with a given GID.
		_tiles[ column + row * columns] = id;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Gets a tile symbol at a given location. 
	 * 
	 * @param  column :Int          The column (x coordinate)
	 * @param  row    :Int          The row (y coordinate)
	 */
	public inline function getTile(column :Int, row :Int) :Int
	{
		// Sets a tile with a given GID.
		return _tiles[ column + row * columns];
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Clears the contents of this layer.
	 * @return [description]
	 */
	public function fill(id :Int) :TileSprite
	{
		var ii :Int = _tiles.length;
		while(ii-->0) {
			_tiles[ii] = id;
		}
		return this;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Fills the layer with empty tiles.
	 * @return [description]
	 */
	public function clear() :TileSprite
	{
		fill(0);
		return this;
	}


	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Copies another tile sprite's tiles onto this layer. The two sprites must be the same size.
	 * 
	 * @param  layer  :MapLayer     The layer to copy from.
	 * @return        [description]
	 */
	public function copyFrom(tileSprite :TileSprite, ?copyBlanks :Bool) :TileSprite
	{
		for (x in 0...columns) {
			for (y in 0...rows) {
				var id :Int = tileSprite.getTile(x, y);
				if (copyBlanks || id > 0) {
					setTile(x, y, id);
				}
			}
		}
		return this;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Safely gets a symbol by id. If the id is out of range, return null.
	 * @param  gid :Int          [description]
	 * @return     [description]
	 */
	public function getSymbol(id :Int, ?require :Bool = true) :TileSymbol
	{
		#if debug Assert.that(!require || (id < symbols.length && id > 0), "Symbol must be in range.", [id]); #end
		if (id < 1 || id >= symbols.length) {
			return null;
		}

		return symbols[id];
	}

	/* ---------------------------------------------------------------------------------------- */
	
	override public function draw(g :Graphics)
	{
		if (!this.visible || this.alpha._ == 0)
			return;

		// Calculate the area we should draw to. This is a must especially for larger maps.
		var columnLength :Int = columns;
		var rowLength :Int = rows;
		var sX :Float = 0;
		var sY :Float = 0;
		if (region != null) {
			sX = region.x;
			sY = region.y;
			columnLength = FMath.clamp( Math.ceil( (region.width + tileWidth) / tileWidth), 0, Math.ceil( (columns * tileWidth + sX) / tileWidth) );
			rowLength = FMath.clamp( Math.ceil( (region.height + tileHeight) / tileHeight), 0, Math.ceil( (rows * tileHeight + sY) / tileHeight) );
		}

		for (x in 0...columnLength) {
			var tileX :Int = Math.floor(x - (sX / tileWidth));
			var paintX :Float = tileX * tileWidth;

			for (y in 0...rowLength) {
				var tileY :Int = Math.floor(y - (sY / tileHeight));
				var paintY :Float = tileY * tileHeight;
				var gid = _tiles[ tileX + tileY * columns]; // The GID of the tile.

				if (gid > 0) {
					var symbol = symbols[gid];
					g.drawSubTexture(symbol.atlas, paintX, paintY, symbol.x, symbol.y, symbol.width, symbol.height);
				}
			}
		}
	}

	/* ---------------------------------------------------------------------------------------- */
	
	/**
	 * Gets a column and row tile coordinate from an X and Y in global space. Useful for converting pointer x,y to local columns and rows.
	 * 
	 * @param  x      :Float        [description]
	 * @param  y      :Float        [description]
	 * @param  ?reuse :Point        [description]
	 * @return        [description]
	 */
	public function getColumnRow(x :Float, y :Float, ?reuse :Point) :Point
	{
		if (reuse == null) {
			reuse = new Point();
		}

		this.getViewMatrix().inverseTransform(x, y, reuse);
		reuse.x = Math.floor(reuse.x / tileWidth);
		reuse.y = Math.floor(reuse.y / tileHeight);

		return reuse;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	override public function getNaturalWidth() :Float
	{
		return columns * tileWidth;
	}

	/* ---------------------------------------------------------------------------------------- */
	
	override public function getNaturalHeight() :Float
	{
		return rows * tileHeight;
	}
}