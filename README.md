# FlxPlatformerPathfinder
I don't share WIPs like this often so it may look stupid, it doesn't work, yet but it may be the foundation of something that does

GOOD LUCK!

[FlxPathfinder](https://github.com/Geokureli/FlxPlatformerPathfinder/blob/main/source/flixel/tile/FlxPathfinder.hx) is the base Pathfinding class. There's been a [PR made for it to haxeflixel](https://github.com/HaxeFlixel/flixel/pull/2480). [FlxPlatformerPathfinder](https://github.com/Geokureli/FlxPlatformerPathfinder/blob/main/source/flixel/tile/FlxPlatformerPathfinder.hx) is the extended class meant to look for platforms to jump to. it doesn't actually simulate the jump arc yet, and it just spits out a list of points, in the end `FlxPlatformerPathfinderData` would include data wether a node was reached via walking or jumping which would be converted into some kind of move sequence data - holy crap this is a huge task.
