package util;

import haxe.CallStack;

class CrashLogger
{
    public static function install():Void
    {
        // Install platform-level handlers where available.
        #if cpp
        try { untyped __global__.__hxcpp_set_critical_error_handler(onCriticalError); } catch (_:Dynamic) {}
        #end

        #if openfl
        try {
            // OpenFL uncaught error events (if available) - access stage as Dynamic to avoid hxcpp casting issues
            var st:Dynamic = null;
            try { st = (cast openfl.Lib.current.stage : Dynamic); } catch (_:Dynamic) {}
            if (st != null && Reflect.hasField(st, "uncaughtErrorEvents"))
            {
                try {
                    var ev:Dynamic = Reflect.field(st, "uncaughtErrorEvents");
                    var addFn = Reflect.field(ev, "addEventListener");
                    try { Reflect.callMethod(ev, addFn, [openfl.events.UncaughtErrorEvent.UNCAUGHT_ERROR, onUncaughtOpenFL]); } catch (_:Dynamic) {}
                } catch (_:Dynamic) {}
            }
        } catch (_:Dynamic) {}
        #end
    }

    static function onCriticalError(msg:String):Void
    {
        logException(msg);
    }

    static function onUncaughtOpenFL(e:Dynamic):Void
    {
        try
        {
            logException(e);
            // prevent default propagation when possible
            try { e.stopImmediatePropagation(); } catch (_:Dynamic) {}
        }
        catch (_:Dynamic) {}
    }

    public static function logException(e:Dynamic):Void
    {
        try
        {
            var msg = Std.string(e);
            try { if (Globals.log != null) Globals.log.line('[FATAL] Unhandled: ' + msg); } catch (_:Dynamic) {}

            // Try to include a CallStack if available
            try
            {
                var stack = CallStack.exceptionStack();
                if (stack != null)
                {
                    for (frame in stack)
                    {
                        try { if (Globals.log != null) Globals.log.line('  ' + CallStack.toString([frame])); } catch (_:Dynamic) {}
                    }
                }
            }
            catch (_:Dynamic) {}
        }
        catch (_:Dynamic) {}
    }

    public static function safeCall(f:Void->Void):Void
    {
        try
        {
            f();
        }
        catch (e:Dynamic)
        {
            logException(e);
        }
    }
}
