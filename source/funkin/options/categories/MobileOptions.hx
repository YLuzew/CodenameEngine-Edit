package funkin.options.categories;

import flixel.input.keyboard.FlxKey;
import lime.system.System as LimeSystem;
import funkin.backend.assets.ModsFolder;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class MobileOptions extends TreeMenuScreen
{
	inline public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [];
		daList = string.trim().split('\n');
		trace(daList);

		return daList;
	}
	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = null;
		if(Assets.exists(path)) daList = Assets.getText(path);
		trace(daList);
		return daList != null ? listFromString(daList) : [];
	}

	inline public static function mergeAllTextsNamed(file:String)
	{
		var mergedList:Array<String> = [];
		var list:Array<String> = coolTextFile(file);
		for (value in list)
			if(!mergedList.contains(value) && value.length > 0)
				mergedList.push(value);
		return mergedList;
	}

	#if android
	var storageTypes:Array<String> = ["EXTERNAL_DATA", "EXTERNAL_MEDIA", "EXTERNAL"];
	var customPaths:Array<String> = MobileUtil.getCustomStorageDirectories(false);
	final lastExternal:String = Options.storageType;
	var externalOption:ArrayOption;
	#end

	var HitboxModes:Array<String>;
	var padCustomOption:TextOption;
	var playModeOption:ArrayOption;
	public function new()
	{
		super('optionsTree.mobile-name', 'optionsTree.mobile-name', 'MobileOptions.', ['FULL', 'A_B']);
		#if android
		storageTypes = storageTypes.concat(customPaths); //Get Custom Paths From File
		#end

		HitboxModes = mergeAllTextsNamed("assets/mobile/Hitbox/hitboxModeList.txt");
		if ((HitboxModes == null))
			HitboxModes = ["Normal"];

		add(new NumOption(getNameID('extraButtons'), getDescID('extraButtons'), 0, 2, 1, 'extraButtons'));
		add(playModeOption = new ArrayOption(getNameID('mobileControlMode'), getDescID('mobileControlMode'), [0, 1, 2, 3, 4],
			['Pad-Right', 'Pad-Left', 'Pad-Custom', 'Hitbox', 'Official'], 'mobileControlMode', __changePlayMode));
		#if TOUCH_CONTROLS
		// 只有 Play Mode 选到 Pad-Custom 时才可点，否则灰掉
		add(padCustomOption = new TextOption(getNameID('padCustomize'), getDescID('padCustomize'), ' >', __openPadCustomize));
		padCustomOption.locked = (Options.mobileControlMode != 2);
		#end
		#if TOUCH_CONTROLS
		add(new NumOption(getNameID('hitboxAlpha'), getDescID('hitboxAlpha'), 0, 100, 5, 'hitboxAlpha'));
		add(new Checkbox(getNameID('oldPadTexture'), getDescID('oldPadTexture'), 'oldPadTexture', __changePadTexture));
		add(new NumOption(getNameID('touchPadAlpha'), getDescID('touchPadAlpha'), 0, 100, 5, 'touchPadAlpha'));
		add(new ArrayOption(getNameID('hitboxType'), getDescID('hitboxType'), ['noGradient', 'noGradientOld', 'gradient', 'hidden'],
			["No Gradient", "No Gradient (Old)", "Gradient", "Hidden"], 'hitboxType'));
		add(new Checkbox(getNameID('hitboxPos'), getDescID('hitboxPos'), 'hitboxPos'));
		#end
		/* Tahtalı Köy, can be added back later.
		add(new ArrayOption(getNameID('hitboxType'), getDescID('hitboxType'), ["No Gradient", "No Gradient (Old)", "Gradient"],
			["No Gradient", "No Gradient (Old)", "Gradient"], 'hitboxType'));
		*/
		add(new ArrayOption(getNameID('hitboxMode'), getDescID('hitboxMode'), HitboxModes, HitboxModes, 'hitboxMode'));

		add(new NumOption(getNameID('controlsAlpha'), getDescID('controlsAlpha'), 0.0, 1.0, 0.1, "controlsAlpha", (alpha:Float) ->
		{
			//MusicBeatState.instance.mobileManager.alpha = alpha;
			if (funkin.backend.system.Controls.instance.mobileC)
			{
				FlxG.sound.volumeUpKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.muteKeys = [];
			}
			else
			{
				FlxG.sound.volumeUpKeys = [FlxKey.PLUS, FlxKey.NUMPADPLUS];
				FlxG.sound.volumeDownKeys = [FlxKey.MINUS, FlxKey.NUMPADMINUS];
				FlxG.sound.muteKeys = [FlxKey.ZERO, FlxKey.NUMPADZERO];
			}
		}));

		#if android
		add(externalOption = new ArrayOption(getNameID('storageType'), getDescID('storageType'), storageTypes,
			storageTypes, 'storageType'));
		#end
	}

	private function __openPadCustomize() {
		#if TOUCH_CONTROLS
		if (Options.mobileControlMode != 2) return;
		var st = MusicBeatState.instance;
		if (st != null) st.openSubState(new mobile.funkin.backend.system.MobileControlSelectSubState());
		#end
	}

	private function __changePlayMode(value:Dynamic) {
		#if TOUCH_CONTROLS
		mobile.funkin.backend.utils.MobileData.mode = cast value;
		var s = MusicBeatState.instance;
		if (s != null) s.applyMobileControlMode();
		if (padCustomOption != null) padCustomOption.locked = (mobile.funkin.backend.utils.MobileData.mode != 2);
		#end
	}

	private function __changePadTexture() {
		#if TOUCH_CONTROLS
		var s = MusicBeatState.instance;
		if (s != null) {
			s.removeMobileControls();
			s.addMobileControls();
			if (s.mobileControls != null && s.mobileControls.instance != null)
				s.mobileControls.instance.visible = true;
		}
		#end
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		#if TOUCH_CONTROLS
		// Pad Customize 界面里改过模式的话，把状态同步回来
		final curMode:Int = mobile.funkin.backend.utils.MobileData.mode;
		if (Options.mobileControlMode != curMode) Options.mobileControlMode = curMode;
		if (padCustomOption != null) padCustomOption.locked = (curMode != 2);
		if (playModeOption != null && playModeOption.currentSelection != curMode) playModeOption.currentSelection = curMode;
		#end
	}

	override function close()
	{
		super.close();

		#if android
		if (lastExternal != externalOption.displayOptions[externalOption.currentSelection])
		{
			Options.save();
			File.saveContent(MobileUtil.getStorageTypePath(), Options.storageType);
			MobileUtil.initDirectory();
			persistentUpdate = false;
			funkin.backend.utils.NativeAPI.showMessageBox(TU.translate('MobileOptions.storageTypeChange-title'), TU.translate('MobileOptions.storageTypeChange-body'));
			LimeSystem.exit(1);
		}
		#end
	}
}