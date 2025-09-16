package util;
#if (windows && cpp)
@:cppInclude("Windows.h")
extern class WinAPI {
    @:native("FindWindowA")
    public static function FindWindowA(className:cpp.ConstCharStar, windowName:cpp.ConstCharStar):cpp.Pointer<cpp.Void>;
}
#end
