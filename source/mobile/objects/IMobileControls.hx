package mobile.objects;

#if TOUCH_CONTROLS
import flixel.util.FlxSignal.FlxTypedSignal;

/**
 * ...
 * @author: Karim Akra
 */
interface IMobileControls
{
	public var buttonLeft:TouchButton;
	public var buttonUp:TouchButton;
	public var buttonRight:TouchButton;
	public var buttonDown:TouchButton;
	public var buttonExtra:TouchButton;
	public var buttonExtra2:TouchButton;
	public var instance:MobileInputManager;
}
#end