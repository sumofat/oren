package platform
//NOTE(Ray):Ripped this from 
//https://github.com/SentientCoffee/CappuccinoEngine-v3/blob/master/src/logger.odin
//probably wont use it but leaving it here might use it / modify it some time
// bbad naming conventions windows only


import "core:fmt";
import "core:intrinsics";
import "core:log";
import "core:runtime";
import "core:strings";
import win32 "core:sys/windows"

@(private="file") Logger  :: runtime.Logger;
@(private="file") Level   :: runtime.Logger_Level;
@(private="file") Options :: runtime.Logger_Options;

@(private="file") DefaultLoggerOptions :: Options{ .Level, .Terminal_Color };

Trace   :: Level(0);
Debug   :: Level(5);
Info    :: Level.Info;
Warning :: Level.Warning;
Error   :: Level.Error;
Fatal   :: Level.Fatal;


createConsoleLogger :: proc(lowestLevel := Level.Debug, opt := DefaultLoggerOptions) -> (logger : Logger) {
    return Logger {
        data = nil,
        lowest_level = lowestLevel,
        options = opt,
        procedure = consoleLoggerProc,
    };
}

// -----------------------------------------------------------------------------------

dumpLastError :: #force_inline proc(fmtString : string, args : ..any) {
    using win32
    str := fmt.tprintf(fmtString, ..args);
    err := GetLastError();
    logError("Windows", "{}\nLast error: {} (0x{:x})", str, err, cast(u32) err);
}

logTrace :: #force_inline proc(ident : string, fmtString : string, args : ..any) {
    str := fmt.tprintf(fmtString, ..args);
    log.logf(Trace, "[{}]: {}\n", ident, str);
}

logDebug :: #force_inline proc(ident : string, fmtString : string, args : ..any) {
    str := fmt.tprintf(fmtString, ..args);
    log.logf(Debug, "[{}]: {}\n", ident, str);
}

logInfo :: #force_inline proc(ident : string, fmtString : string, args : ..any) {
    str := fmt.tprintf(fmtString, ..args);
    log.logf(Info,"[{}]: {}\n", ident, str);
}

logWarning :: #force_inline proc(ident : string, fmtString : string, args : ..any) {
    str := fmt.tprintf(fmtString, ..args);
    log.logf(Warning, "[{}]: {}\n", ident, str);
}

logError :: #force_inline proc(ident : string, fmtString : string, args : ..any) {
    str := fmt.tprintf(fmtString, ..args);
    log.logf(Error, "{} fail! {}\n", ident, str);
}

logFatal :: #force_inline proc(ident : string, fmtString : string, args : ..any) {
    str := fmt.tprintf(fmtString, ..args);
    log.logf(Fatal, "FATAL {} fail! {}\n", ident, str);
    when ODIN_DEBUG do intrinsics.debug_trap() else do intrinsics.trap();
}

// -----------------------------------------------------------------------------------

@(private="file")
consoleLoggerProc :: proc(data : rawptr, level : Level, text : string, options : Options, location := #caller_location) {
    WHITE  :: "\x1b[0m";
    RED    :: "\x1b[91m";
    GREEN  :: "\x1b[92m";
    YELLOW :: "\x1b[33m";
    CYAN   :: "\x1b[36m";

    // @Note(Daniel): Not using data parameter

    col := WHITE;
    if .Level in options {
        if .Terminal_Color in options {
            switch level {
                case Trace:   col = WHITE;
                case Debug:   col = CYAN;
                case Info:    col = GREEN;
                case Warning: col = YELLOW;
                case Error:   fallthrough;
                case Fatal:   col = RED;
            }
        }
    }

    fmt.printf("{}{}{}", col, text, WHITE);
    OutputDebugStringW(format_cstr(text));
}

@(private="file")
format_cstr :: #force_inline proc(fmtString : string, args : ..any) -> cstring {
    debugStr  := fmt.tprintf(fmtString, ..args);
    return strings.clone_to_cstring(debugStr, context.temp_allocator);
}