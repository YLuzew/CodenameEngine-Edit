package;

#if !macro
import funkin.options.Options;
import funkin.backend.utils.NativeAPI;
import funkin.backend.assets.ModsFolder;

#if TOUCH_CONTROLS
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.sound.FlxSound;
import funkin.backend.assets.Paths;
import funkin.backend.utils.CoolUtil;
import mobile.objects.TouchButton;
import mobile.objects.TouchPad;
import mobile.objects.IMobileControls;
import mobile.funkin.backend.utils.MobileData;
import mobile.funkin.backend.system.input.MobileInputID;
import mobile.funkin.backend.system.input.MobileInputManager;
#end

#if sys
import sys.io.File;
import sys.FileSystem;
#end

#if android
import android.content.Context as AndroidContext;
import android.widget.Toast as AndroidToast;
import android.os.Environment as AndroidEnvironment;
import android.Permissions as AndroidPermissions;
import android.Settings as AndroidSettings;
import android.Tools as AndroidTools;
import android.os.Build.VERSION as AndroidVersion;
import android.os.Build.VERSION_CODES as AndroidVersionCode;
#end

#end
