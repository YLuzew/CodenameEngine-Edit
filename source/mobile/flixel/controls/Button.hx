package mobile.flixel.controls;

#if flixel
/**
 * Mobile touch button.
 *
 * Same as the `mobile-controls` one, except that `id` may be an **array** so a
 * single button can drive several actions at once -- a touch pad direction has to
 * report both `LEFT` (menu / scrolling) and `NOTE_LEFT` (hitting notes).
**/
class Button extends InputHandler {
	public var controlID:String;
	public var controlIDs:Array<String> = [];

	public function new(data:ControlDef) {
		super(data.position != null ? data.position[0] : 0, data.position != null ? data.position[1] : 0, false);
		jsonName = data.name;

		var ids:Array<String> = [];
		if (Std.isOfType(data.id, Array)) {
			for (i in (cast data.id : Array<Dynamic>)) {
				if (i != null)
					ids.push(Std.string(i));
			}
		} else if (data.id != null) {
			ids.push(Std.isOfType(data.id, String) ? cast data.id : Std.string(data.id));
		}
		controlIDs = ids;
		controlID = ids.length > 0 ? ids[0] : null;

		var subData = parseSubGraphic(data);
		var scaleFloat:Float = 1.0;
		if (data.scale != null) {
			if (Std.isOfType(data.scale, Array)) {
				var arr:Array<Float> = cast data.scale;
				scaleFloat = arr[0];
			} else {
				scaleFloat = cast data.scale;
			}
		}
		loadElementGraphics(data.texture, subData.subTex, data.spritesheet, [Config.BUTTON_PATH, Config.MODDED_BUTTON_PATH], data.color, scaleFloat,
			subData.subColor);
	}

	override public function updateInputs() {
		var isPressed = checkOverlap(baseGraphic);
		if (isPressed) {
			for (id in controlIDs)
				activeIDs.push(id);
		}
		applyBrightness(isPressed);
	}
}
#end
