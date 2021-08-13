package fmj

import "core:fmt"
import "core:c"

foreign import fmj "../../library/fmj/build/fmj.lib"

FMJTicketMutex :: struct
{
    ticket : i64,
    serving : i64,
};
 
f2 :: struct
{
    x : f32,
    y: f32,
}
 
f3 :: struct
{
    x : f32,
    y: f32,
    z: f32,
}
 
f4 :: struct
{
    x : f32,
    y : f32,
    z : f32,
    w : f32,
}

quaternion :: f4;

f4x4 :: struct
{
    c0 : f4,
    c1 : f4,
    c2 : f4,
    c3 : f4,
};

@(default_calling_convention="c")
foreign fmj
{
    degrees :: proc "c" (x : f32) -> f32 ---;
    radians :: proc "c" (x : f32) -> f32 ---;
    fmj_thread_begin_ticket_mutex :: proc "c"(mutex : ^FMJTicketMutex) ---;
    fmj_thread_end_ticket_mutex :: proc "c"(mutex : ^FMJTicketMutex) ---;    
}


