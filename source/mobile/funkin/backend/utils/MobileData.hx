package mobile.funkin.backend.utils;

#if TOUCH_CONTROLS
import haxe.ds.Map;
import haxe.Json;
import haxe.io.Path;
import openfl.utils.Assets;
import flixel.util.FlxSave;

/**
 * ...
 * @author: Karim Akra
 */
class MobileData
{
	public static var actionModes:Map<String, TouchButtonsData> = new Map();
	public static var dpadModes:Map<String, TouchButtonsData> = new Map();

	public static var mode(get, set):Int;
	public static var forcedMode:Null<Int>;
	public static var save:FlxSave;

	public static function init()
	{
		save = new FlxSave();
		save.bind('MobileControls', flixel.FlxG.stage.application.meta.get('company'));

		setDefaultMap('assets/mobile/DPadModes', dpadModes);
		setDefaultMap('assets/mobile/ActionModes', actionModes);
		#if MOD_SUPPORT
		final moddyFolder:String = (ModsFolder.currentModFolder != null
			&& ModsFolder.currentModFolder != "default") ? '${ModsFolder.modsPath}${ModsFolder.currentModFolder}/mobile' : '';
		if (FileSystem.exists(moddyFolder) && FileSystem.isDirectory(moddyFolder))
		{
			setModMap('$moddyFolder/DPadModes', dpadModes);
			setModMap('$moddyFolder/ActionModes', actionModes);
		}
		#end
	}

	public static function setTouchPadCustom(touchPad:TouchPad):Void
    {
        if (save.data.buttons == null)
        {
            save.data.buttons = new Array();
            for (buttons in touchPad)
                save.data.buttons.push({x: buttons.x, y: buttons.y});
        }
        else
        {
            var tempCount:Int = 0;
            for (buttons in touchPad)
            {
                save.data.buttons[tempCount] = {x: buttons.x, y: buttons.y};
                tempCount++;
            }
        }
    
        save.flush();
    }

    public static function getTouchPadCustom(touchPad:TouchPad):TouchPad
    {
        var tempCount:Int = 0;
    
        if (save.data.buttons == null)
            return touchPad;
    
        for (buttons in touchPad)
        {
            if (save.data.buttons[tempCount] != null)
            {
                buttons.x = save.data.buttons[tempCount].x;
                buttons.y = save.data.buttons[tempCount].y;
            }
            tempCount++;
        }
    
        return touchPad;
    }
	
	public static function clearTouchPadData()
	{
		dpadModes.clear();
		actionModes.clear();
	}

	private static function setDefaultMap(folder:String, map:Map<String, TouchButtonsData>)
	{
		for (file in readDirectory(folder))
		{
			if (Path.extension(file) == 'json')
			{
				file = Path.join([folder, Path.withoutDirectory(file)]);
				var str = Assets.getText(file);
				var json:TouchButtonsData = cast Json.parse(str);
				var mapKey:String = Path.withoutDirectory(Path.withoutExtension(file));
				map.set(mapKey, json);
			}
		}
	}

	private static function readDirectory(path:String):Array<String>
	{
		var filteredList:Array<String> = Assets.list().filter(f -> f.startsWith(path));
		var results:Array<String> = [];
		for (i in filteredList.copy())
		{
			var slashsCount:Int = path.split('/').length;
			if (path.endsWith('/'))
				slashsCount -= 1;

			if (i.split('/').length - 1 != slashsCount)
			{
				filteredList.remove(i);
			}
		}
		for (item in filteredList)
		{
			@:privateAccess
			for (library in lime.utils.Assets.libraries.keys())
			{
				var libPath:String = '$library:$item';
				if (library != 'default' && Assets.exists(libPath) && !results.contains(libPath))
					results.push(libPath);
				else if (Assets.exists(item) && !results.contains(item))
					results.push(item);
			}
		}
		return results.map(f -> f.substr(f.lastIndexOf("/") + 1));
	}

	#if MOD_SUPPORT
	private static function setModMap(folder:String, map:Map<String, TouchButtonsData>)
	{
		for (file in FileSystem.readDirectory(folder))
		{
			if (Path.extension(file) == 'json')
			{
				file = Path.join([folder, Path.withoutDirectory(file)]);
				var str = File.getContent(file);
				var json:TouchButtonsData = cast Json.parse(str);
				var mapKey:String = Path.withoutDirectory(Path.withoutExtension(file));
				map.set(mapKey, json);
			}
		}
	}
	#end
	
	static function set_mode(mode:Int = 3)
	{
		save.data.mobileControlsMode = mode;
		save.flush();
		return mode;
	}

	static function get_mode():Int
	{
		if (forcedMode != null)
			return forcedMode;

		if (save.data.mobileControlsMode == null)
		{
			save.data.mobileControlsMode = 3;
			save.flush();
		}

		return save.data.mobileControlsMode;
	}
}

typedef TouchButtonsData =
{
	buttons:Array<ButtonsData>
}

typedef ButtonsData =
{
	button:String, // what TouchButton should be used, must be a valid TouchButton var from TouchPad as a string.
	graphic:String, // the graphic of the button, usually can be located in the TouchPad xml .
	x:Float, // the button's X position on screen.
	y:Float, // the button's Y position on screen.
	color:String // the button color, default color is white.
}
#end
