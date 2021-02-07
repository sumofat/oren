package fmj

import "core:fmt"
import "core:c"

foreign import fmj "../../library/fmj/build/fmj.lib"

FMJMemoryArena :: struct
{
    base : rawptr ,
    aligned_base : rawptr ,
    size : c.uintptr_t,
    used : u32 ,
    temp_count : u32,
};

FMJFixedBuffer :: struct
{
    base : rawptr,
    capacity : c.uintptr_t,
    total_size : c.uintptr_t,
    unit_size  : c.uintptr_t,
    count : c.uintptr_t,
    at_index : u32, 
    start_at : c.int,
    alignment : u32,    
    mem_arena : FMJMemoryArena
};

//Stretchy 
FMJStretchBuffer :: struct
{
    fixed : FMJFixedBuffer,
    resize_ratio : f32, //0.1 10% 1 100% default is 50% or 1/2 resizing
    alignment_offset : u32,
    borrow_count : u64
};

FMJHashTable :: struct
{
    key_backing_array : FMJStretchBuffer, 
    keys : FMJFixedBuffer,
    values : FMJFixedBuffer,
    collisions : FMJStretchBuffer, 
    collision_free_list : FMJStretchBuffer,
    table_size : u64,
    collision_count : u64,
    key_size : u64,
    key_value : u64
};

AnyCache :: struct
{
    hash : FMJHashTable,
    key_size : c.uintptr_t,
    is_init : bool,
    anythings : FMJStretchBuffer,
    is_using_free_list : bool,
    free_list : FMJStretchBuffer,
};

FMJTicketMutex :: struct
{
    ticket : i64,
    serving : i64
};
 
f2 :: struct
{
    x : f32,
    y: f32
}
 
f4 :: struct
{
    x : f32,
    y : f32,
    z : f32,
    w : f32,
}

@(default_calling_convention="c")
foreign fmj
{
    degrees :: proc "c" (x : f32) -> f32 ---;
    radians :: proc "c" (x : f32) -> f32 ---;
    fmj_thread_begin_ticket_mutex :: proc "c"(mutex : ^FMJTicketMutex) ---;
    fmj_thread_end_ticket_mutex :: proc "c"(mutex : ^FMJTicketMutex) ---;    
}


