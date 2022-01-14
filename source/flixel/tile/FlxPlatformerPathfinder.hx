package flixel.tile;

import flixel.math.FlxVector;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.tile.FlxBaseTilemap;
import flixel.tile.FlxPathfinder;
import flixel.util.FlxDirectionFlags;

class FlxPlatformerPathfinder extends FlxTypedPathfinder<FlxPlatformerPathfinderData>
{
	public var jumpHeight:Float;
	public var timeToApex:Float;
	public var maxVelocity:FlxPoint;
	public var height:Float;
	public var flatJumpDistance:Float;
	
	/**
	 * All params are units of tiles
	 * @param jumpHeight  The jump height, in tiles
	 * @param timeToApex  The seconds it takes to reach the peak
	 * @param maxVelocity In tiles per second
	 * @param height      In tiles, might just make this one an Int
	 */
	public function new (jumpHeight:Float, timeToApex:Float, maxVelocity:FlxPoint, height:Float = 0)
	{
		this.jumpHeight = jumpHeight;
		this.timeToApex = timeToApex;
		this.maxVelocity = maxVelocity;
		flatJumpDistance = 2 * timeToApex * maxVelocity.x;
		
		super(FlxPlatformerPathfinderData.new.bind(this, _, _, _));
	}
	
	public function findPathFromJumper(map:FlxTilemap, jumper:FlxObject, end:FlxPoint)
	{
		var start = jumper.getPosition();
		start.x += jumper.width / 2;
		start.y += jumper.height - (map.height / map.heightInTiles / 2);
		return findPath(cast map, start, end);
	}
	
	public function findPathFromJumperToMouse(map, jumper)
	{
		return findPathFromJumper(cast map, jumper, FlxG.mouse.getWorldPosition());
	}
	
	public function findPathIndicesFromJumper(map:FlxTilemap, jumper:FlxObject, endIndex:Int)
	{
		var startPos = jumper.getPosition();
		startPos.x += jumper.width / 2;
		startPos.y += jumper.height - (map.height / map.heightInTiles / 2);
		return findPathIndices(cast map, map.getTileIndexByCoords(startPos), endIndex);
	}
	
	public function findPathIndicesFromJumperToMouse(map, jumper)
	{
		return findPathIndicesFromJumper(map, jumper, map.getTileIndexByCoords(FlxG.mouse.getWorldPosition()));
	}
	
	override function getNeighbors(data:Data, from:Int)
	{
		var x = data.getX(from);
		var y = data.getY(from);
		var cols = data.map.widthInTiles;
		var rows = data.map.heightInTiles;
		var left = x > 0;
		var right = x < cols - 1;
		var up = y > 0;
		var down = y < cols - 1;
		
		var neighbors = [];
		inline function addIfStand(condition = true, to)
		{
			if (condition && data.canStand(to))
				neighbors.push(to);
		}
		
		if (data.canStand(from))
		{
			// only walk 1 tile at a time
			addIfStand(right, from + 1);
			addIfStand(left, from - 1);
			
			var jumpDistanceInt = Std.int(flatJumpDistance);
			var top = y - Math.floor(jumpHeight);
			if (top < 0) top = 0;
			
			var left = x - jumpDistanceInt;
			if (left < 0) left = 0;
			
			var right = x + jumpDistanceInt;
			if (right < 0) right = 0;
			
			for (toY in top...rows)
			{
				for (toX in left...right)
				{
					final to = toY * cols + toX;
					if (data.canStand(to) && data.canWalk(from, to) == false && data.canJump(from, to))
						neighbors.push(to);
				}
			}
		}
		else
		{
			// we are not standing, this is likely the objects's current position
			// Todo: See what we can fall on
		}
		
		return neighbors;
	}
	
	override function getDistance(data:Data, from:Int, to:Int):Int
	{
		if (from + 1 == to || from - 1 == to)
			return 1;
		
		//Todo: slopes
		
		// assume we're jumping there
		var fromX = data.getX(from);
		var fromY = data.getY(from);
		var toX = data.getX(to);
		var toY = data.getY(to);
		if (toY < fromY)
		{
			var xDis = to > from ? to - from : from - to;
			return xDis + Std.int(jumpHeight) * 2 + from - to;
		}
		
		return toY - fromY;
	}
	
	override function isTileSolved(data:Data, tile:Int):Bool
	{
		return false;
	}
	
	/**
	 * Does math magic to determine constructor vars
	 * @param tileSize     in pixels
	 * @param jumpVelocity The upward force when jumping, should be positive
	 * @param gravity      The downward force bringing you back, should be positive
	 * @param maxVelocity  in pixels
	 * @param height       the jumper's height in pixels
	 */
	static public function createSimple
		( tileSize:FlxPoint
		, jumpVelocity:Float
		, gravity:Float
		, maxVelocity:FlxPoint
		, height:Float
		)
	{
		// vf(0) = vi + a*t | where vf=0 (apex)
		// -> -vi = a*t
		// -> -vi / a = t | jumpV is pre-negated so | vi / a = t
		var timeToApex = jumpVelocity / gravity;
		// d = t * (vi + vf(0)) / 2 | where vf=0 (apex)
		// -> d = t * vi / 2
		var jumpHeight = timeToApex * jumpVelocity / 2;
		var pathfinder = new FlxPlatformerPathfinder
			( jumpHeight / tileSize.y
			, timeToApex
			, FlxPoint.get(maxVelocity.x / tileSize.x, maxVelocity.y / tileSize.y)
			, height / tileSize.y
			);
		
		tileSize.putWeak();
		
		return pathfinder;
	}
	
	static public function fromObject(obj:FlxObject, jumpVelocity:Float, tileSize:FlxPoint)
	{
		return createSimple(tileSize, jumpVelocity, obj.acceleration.y, obj.maxVelocity, obj.height);
	}
}

typedef Data = FlxPlatformerPathfinderData;

@:allow(flixel.tile.FlxPlatformerPathfinder)
@:access(flixel.tile.FlxPlatformerPathfinder)
private class FlxPlatformerPathfinderData extends FlxPathfinderData
{
	/** Every tile in the map the platformer can stand on */
	var platforms:Array<Bool>;
	
	/** List of tiles you can jump to (listed as the difference of indices from any tile) */
	var inJumpReach:Array<Int>;
	
	public function new (pathfinder:FlxPlatformerPathfinder, map, start, end)
	{
		super(map, start, end);
		
		platforms =
		[
			for (i in 0...map.totalTiles)
				canPhysicallyStand(pathfinder, i)
		];
		
		var jumpReach = Std.int(pathfinder.flatJumpDistance);
		
		inJumpReach = [];
		var cols = map.widthInTiles;
		for (y in -Math.floor(pathfinder.jumpHeight)...1)
		{
			for (x in -jumpReach...jumpReach + 1)
			{
				if (canPhysicallyJumpTo(pathfinder, x, y))
					inJumpReach.push(y * cols + x);
			}
		}
		
		// no reason to jump to an adjacent tile
		inJumpReach.remove(-1);
		inJumpReach.remove(1);
		
	}
	
	function canPhysicallyJumpTo(pathfinder:FlxPlatformerPathfinder, x:Int, y:Int)
	{
		// You can reach it if it's at the same y, or half your jump distance and not directly over head
		if (y == 0 || (Math.abs(x) * 2 < pathfinder.flatJumpDistance && x != 0))
			return true;
		
		//Todo:check actual physics
		
		return false;
	}
	
	function canPhysicallyStand(pathfinder:FlxPlatformerPathfinder, index:Int):Bool
	{
		var x = getX(index);
		var y = getY(index);
		var cols = map.widthInTiles;
		var rows = map.heightInTiles;
		
		// prevent them from jumping so their head is above the camera.
		var objHeightInt = Math.ceil(pathfinder.height); 
		if (y < objHeightInt)
			return false;
		
		// Make sure there's no walls directly above this spot
		var i = objHeightInt;
		while (i-- > 0)
		{
			var aboveIndex = index - cols * i;
			if (aboveIndex > 0 || getTileCollisionsByIndex(index) != NONE)
				return false;
		}
		
		// has floor beneath
		return y < rows - 1
			&& (getTileCollisionsByIndex(index + cols):FlxDirectionFlags).has(FLOOR);
	}
	
	function canStand(index:Int):Bool
	{
		return platforms[index];
	}
	
	function canWalk(from:Int, to:Int)
	{
		if (canStand(to) == false)
			return false;
		
		var yFrom = getY(from);
		var yTo = getY(to);
		if (yTo < yFrom)
		{
			//Todo: check slopes
			return false;
		}
		
		if (yFrom == yTo)
		{
			var iter = 1;
			var dir = FlxDirectionFlags.LEFT;//check if `to` allows from left
			if (to < from)
			{
				dir = LEFT;
				iter = -1;
			}
			
			var i = from;
			while (i != to)
			{
				if (canStand(i) == false)
					return false;
				i += iter;
			}
			
			return true;
		}
		
		// If `to` is below from and can stand
		
		// Todo: see if we can fall to it without jumping. for now handle this with jumping
		return false;
	}
	
	function canFallTo(from:Int, to:Int)
	{
		//Todo: check if we can fall there
		return getY(from) < getY(to);
	}
	
	function canJump(from:Int, to:Int)
	{
		var xDis = getX(to) - getX(from);
		var yDis = getY(to) - getY(from);
		
		//Todo: check if it's not blocked by a wall
		
		return yDis > 0
			|| inJumpReach.indexOf(yDis * map.widthInTiles + xDis) != -1;
	}
}