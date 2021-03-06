package containers;

import "core:fmt"
import "core:c"
import "core:mem"

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

buf_pop :: proc(buffer : ^Buffer($element_type)) -> (element_type)
{
    assert(buffer != nil);
    //should reduce length by 1 and remove the top element
    return pop(&buffer.buffer);
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

buf_ptr :: proc(buffer : ^Buffer($element_type),index : u64) -> (^element_type)
{
    assert(buffer != nil);
    if (len(buffer.buffer) == 0)
    { 
        return nil;   
    }
    return &buffer.buffer[index];    
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

buf_clear :: proc(b : ^Buffer($element_type))
{
    assert(b != nil);
    clear(&b.buffer);
    b.current_id = 0;
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
