package graphics;

import "core:fmt"
import "core:c"
import "core:mem"

import platform "../platform"
import fmj "../fmj"

Buffer :: struct (type : typeid)
{
    buffer : [dynamic]type,
    current_id : u64,
    borrow_count : u64,
}

buf_init :: proc(capacity : u64,$type : typeid) -> (Buffer(type))
{
    result : Buffer(type);
    result.buffer = make([dynamic]type,0,capacity);
    return result;
}

buf_push :: proc(buffer : ^Buffer($element_type),element : element_type) -> u64
{
    assert(buffer != nil);
    assert(buffer.borrow_count == 0);
    if buf_len(buffer^) <= buffer.current_id
    {
	append_nothing(&buffer.buffer);
    }
    
    buffer.buffer[buffer.current_id] = element;
    index := buffer.current_id;
    buffer.current_id = index + 1;
    return index;
}

buf_get :: proc(buffer : ^Buffer($element_type),index : u64) -> (element_type)
{
    assert(buffer != nil);
    return buffer.buffer[index];
}

buf_get_nb :: proc(buffer : ^Buffer($element_type),index : u64,$type : typeid) -> (type) #no_bounds_check
{
    assert(buffer != nil);
    return buffer.buffer[index];
}

buf_pop :: proc(buffer : ^Buffer($element_type),$type : typeid)
{
    assert(buffer != nil);
    //should reduce length by 1 and remove the top element
    pop(&buffer.buffer);
}

//NOTE(Ray):If somone tries to push an element while a ptr is checked out should assert
buf_chk_out :: proc(buffer : ^Buffer($element_type),index : u64) -> (^element_type)
{
    assert(buffer != nil);
    if (len(buffer.buffer) == 0)
    { 
        return nil;   
    }
    else
    {
        buffer.borrow_count += 1;
        return &buffer.buffer[index];
    }
}

buf_len :: proc(buf : Buffer($element_type)) -> u64
{
    return cast(u64)len(buf.buffer);
}

//NOTE(Ray):If somone tries to push an element while a ptr is checked out should assert
//Call this when your done with checkout ptr.
buf_chk_in :: proc(buffer : ^Buffer($element_type))
{
    if buffer.borrow_count > 0
    {
	buffer.borrow_count -= 1;	
    }
}

buf_clr :: proc(b : ^Buffer($element_type))
{
    assert(b != nil);
    //_fixed_buffer_clear(&b->fixed);
    clear(&buffer.buffer);
    b.borrow_count = 0;
}

buf_free :: proc(b : ^Buffer($element_type))
{
    assert(b != nil);
    delete(&buffer.buffer);
    b.borrow_count = 0;
}

buf_copy :: proc(buf : ^Buffer($element_type),copy_contents : bool  = false) -> Buffer(element_type)
{
    assert(buf != nil);
    result : Buffer(element_type);
    result.current_id = buf.current_id;
    result.borrow_count = buf.borrow_count;
    //    result.buffer = clone_dynamic_array(buf.buffer);
    resize(&result.buffer,len(buf.buffer));
    copy(result.buffer[:],buf.buffer[:]);        
    return result;
}

clone_dynamic_array :: proc(x: $T/[dynamic]$E) -> T
{
    res := make(T, len(x));
    copy(res[:], x[:]);
    return res;
}

/*
//stretchy style
sbuf_init :: proc(capacity : umm,$type : typeid) -> (FixBuffer(type))
{
    result : FixBuffer(type);
    result.buffer = make([dynamic]type,capacity,capacity);
    return result;
}

sbuf_push :: proc(buffer : ^FixBuffer($element_type),element : element_type) -> u64
{
    
}


fixed_buffer_init :: proc(capacity : umm,unit_size : umm , alignment : u32) -> FixedBuffer
{
    assert(unit_size >= alignment);    
    assert(unit_size > 0);
    result : FixedBuffer;
    start_alloc_size : umm = capacity * unit_size + (alignment*capacity);
    result.total_size = 0;
    result.unit_size = unit_size;
    result.capacity = capacity;
    result.alignment = alignment;
    
    result.at_index = 0;
    result.start_at = -1;

    base := alloc(start_alloc_size);//fmj_os_allocate(start_alloc_size);
    result.mem_arena = arena_init(start_alloc_size,base);//fmj_arena_init(start_alloc_size,base);
    result.count = 0;
    
    result.base = result.mem_arena.base;
    
    result.unit_size = unit_size + offset;

    return result;    
}


#define fmj_fixed_buffer_get_ptr(type,buffer,index) (type*)fmj_fixed_buffer_get_(buffer,index);
#define fmj_fixed_buffer_get(type,buffer,index) *(type*)fmj_fixed_buffer_get_(buffer,index);

#define fmj_fixed_buffer_get_any(type,buffer,index) (type*)fmj_fixed_buffer_get_any_(buffer,index);
FMJFixedBuffer fmj_fixed_buffer_init(umm capacity,umm unit_size,u32 alignment);
u64 fmj_fixed_buffer_push(FMJFixedBuffer* buffer, void* element);
void* fmj_fixed_buffer_get_(FMJFixedBuffer* buffer, u64 index);

//NOTE(ray):main difference is that any can access any where inside the buffer
//regardless of push count but based on capacity.
void* fmj_fixed_buffer_get_any_(FMJFixedBuffer* buffer, u64 index);
void fmj_fixed_buffer_clear(FMJFixedBuffer *buffer);
void fmj_fixed_buffer_free(FMJFixedBuffer *buffer);
void fmj_fixed_buffer_pop(FMJFixedBuffer* buffer);

FMJStretchBuffer fmj_stretch_buffer_init(umm capacity,umm unit_size,u32 alignment);
u64 fmj_stretch_buffer_push(FMJStretchBuffer* buffer, void* element);

#define fmj_stretch_buffer_check_out(type,buffer,index) (type*)fmj_stretch_buffer_checkout_ptr_(buffer,index);
#define fmj_stretch_buffer_get(type,buffer,index) *(type*)fmj_stretch_buffer_get_(buffer,index);
void* fmj_stretch_buffer_get_any_(FMJStretchBuffer* buffer,u64 index);
void* fmj_stretch_buffer_checkout_ptr_(FMJStretchBuffer* buffer,u64 index);
void fmj_stretch_buffer_check_in(FMJStretchBuffer* buffer);
 
//WARNING(ray):You get no protection when using this function.
void* fmj_stretch_buffer_get_(FMJStretchBuffer* buffer,u64 index);
void fmj_fixed_buffer_clear_item(FMJFixedBuffer* b,u64 i);
void fmj_stretch_buffer_clear_item(FMJStretchBuffer* s,u64 i);
void fmj_stretch_buffer_clear(FMJStretchBuffer *b);
void fmj_stretch_buffer_free(FMJStretchBuffer *b);
void fmj_stretch_buffer_pop(FMJStretchBuffer* b);
//End Buffer/Collections/DataStructures API
*/
