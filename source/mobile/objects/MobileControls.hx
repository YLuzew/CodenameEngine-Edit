package mobile.objects;

#if TOUCH_CONTROLS
/**
 * ...
 * @author: Karim Akra
 */

import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;

class MobileControls extends FlxTypedSpriteGroup<MobileInputManager>
{
	public var touchPad:TouchPad = new TouchPad('NONE', 'NONE');
	public var hitbox:Hitbox = new Hitbox();

	public function new(?forceType:Int)
	{
		super();
		MobileData.forcedMode = forceType;
		switch (MobileData.mode)
		{
			case 0: // RIGHT_FULL
				initControler(0);
			case 1: // LEFT_FULL
				initControler(1);
			case 2: // CUSTOM
				initControler(2);
			case 3: // HITBOX
				initControler(3);
		}
	}

	private function initControler(controlMode:Int = 0):Void
	{
		switch (controlMode)
		{
			case 0:
				touchPad = new TouchPad('RIGHT_FULL', 'NONE');
				add(touchPad);
			case 1:
				touchPad = new TouchPad('LEFT_FULL', 'NONE');
				add(touchPad);
			case 2:
				touchPad = MobileData.getTouchPadCustom(new TouchPad('RIGHT_FULL', 'NONE'));
				add(touchPad);
			case 3:
				hitbox = new Hitbox();
				add(hitbox);
		}
	}

	override public function destroy():Void
	{
		super.destroy();

		if (touchPad != null)
		{
			touchPad = FlxDestroyUtil.destroy(touchPad);
			touchPad = null;
		}

		if (hitbox != null)
		{
			hitbox = FlxDestroyUtil.destroy(hitbox);
			hitbox = null;
		}
		MobileData.forcedMode = null;
	}
}
#end