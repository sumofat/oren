package containers;

import "core:fmt"
import "core:c"
import "core:mem"

Hash :: struct (key_type,value_type : typeid)
{
    
    hash : map[key_type]value_type,
//    key_size : umm,
    is_init : bool,
//    anythings : Buffer(type),
//    is_using_free_list : bool,
//    free_list : Buffer(type),
};

hash_init :: proc($key_type : typeid,$value_type : typeid) -> Hash(key_type,value_type)
{
    result : Hash(key_type,value_type);
    result.hash = make(map[key_type]value_type);//fmj_hashtable_init_(max_hash_states,size_of_key);
//    result.anythings = buf_init(10,size_of(value_type));
//    result.is_using_free_list = use_free_list;

//    if(use_free_list)
//        result.free_list = fmj_stretch_buffer_init(1,size_of_free_list_entry_index,DEFAULT_ALIGNMENT);
    result.is_init = true;
    return result;
}

hash_exist :: proc(cache : ^Hash($key_type,$value_type),key : key_type) -> bool
{
    return key in cache.hash;
}

hash_add :: proc(cache : ^Hash($key_type,$value_type),key : key_type,thing : value_type)-> bool
{
//    ASSERT(!cache->is_using_free_list);    
//    index := buf_push(&cache.anythings,thing);
//    u32* a = (u32*)index;
    //    FMJHashAddElementResult r = fmj_hashtable_add(&cache->hash,(void*)key,cache->key_size,a);
    cache.hash[key] = thing;
    return true;    
}

hash_get :: proc(cache : ^Hash($key_type,$value_type) ,key : key_type) -> (value_type)
{
//    u32* ptr = fmj_hashtable_get(u32,&cache->hash,(void*)key,cache->key_size);
//    umm index = (umm)ptr;
//    void* result = fmj_stretch_buffer_get_(&cache->anythings, (u32)index);
    //    ASSERT(result);
    result := cache.hash[key];    
    return result;
}

hash_get_ptr :: proc(cache : ^Hash($key_type,$value_type) ,key : key_type) -> (^value_type)
{
//    u32* ptr = fmj_hashtable_get(u32,&cache->hash,(void*)key,cache->key_size);
//    umm index = (umm)ptr;
//    void* result = fmj_stretch_buffer_get_(&cache->anythings, (u32)index);
    //    ASSERT(result);
    result := &cache.hash[key];    
    return result;
}

hash_remove :: proc(cache : ^Hash($key_type,$value_type),key : key_type)
{
//    ASSERT(!cache->is_using_free_list);
    //    _remove(&cache->hash,key);
    delete_key(&cache.hash,key);
}

//BEGIN ANYTHING CACHE
AnyCache :: struct (key_type,value_type : typeid)
{
    hash : Hash(key_type,u64),
    key_size : u64,
    is_init : bool,
    anythings : Buffer(value_type),
    is_using_free_list : bool,
    free_list : Buffer(u64),
}

anycache_init :: proc($key_type,$value_type : typeid,use_free_list : bool)-> AnyCache(key_type,value_type)
{
    result : AnyCache(key_type,value_type);
    result.key_size = size_of(key_type);
    result.hash = hash_init(key_type,u64);
    result.anythings = buf_init(10,value_type);
    result.is_using_free_list = use_free_list;

    if use_free_list
    {
        result.free_list = buf_init(1,u64);
    }
    result.is_init = true;
    return result;
}

anycache_exist :: proc(cache : ^AnyCache($key_type, $value_type),key : key_type) -> bool
{
    return hash_exist(&cache.hash,key);
}

anycache_add_to_free_list :: proc(cache : ^AnyCache($key_type,$value_type),key : key_type,thing : value_type) -> bool
{
    assert(cache.is_using_free_list == true);
    index : u64 = 0;
    if anycache_exist(cache,key)
    {
        assert(false);
        return false;
    }

    if buf_len(cache.free_list) > 0
    {
        mi := buf_get(&cache.free_list,buf_len(cache.free_list) - 1);
        index := mi;
        dst := buf_chk_out(&cache.anythings,index);
	//        fmj_memory_copy(dst,thing,cache->anythings.fixed.unit_size);
	thing_copy := thing;
	mem.copy(dst,&thing_copy,size_of(value_type));	
        buf_chk_in(&cache.anythings);
        buf_pop(&cache.free_list);
    }
    else
    {
        index = buf_push(&cache.anythings,thing);            
    }

    a := index;    
    r := hash_add(&cache.hash,key,a);
    return r;
}

anycache_add :: proc(cache : ^AnyCache($key_type,$value_type),key : key_type,thing : value_type) -> bool
{
    assert(cache.is_using_free_list == false);    
    index : u64  = buf_push(&cache.anythings,thing);
    r := hash_add(&cache.hash,key,index);
    return r;
}

anycache_get_ptr :: proc(cache : ^AnyCache($key_type,$value_type),key : key_type) -> ^value_type
{
    ptr := hash_get_ptr(&cache.hash,key);
    index := ptr^;
    result := buf_ptr(&cache.anythings, index);
    assert(result != nil);
    return result;
}

anycache_chk_out :: proc(cache : AnyCache($key_type,$value_type),key : key_type) -> key_type 
{
    ptr := fmj_hashtable_get(&cache.hash,key);
    index := ptr;
    result := buf_chk_out_ptr(&cache->anythings, index);
    assert(result != nil);
    return result;
}

anycache_checkin :: proc(cache : ^AnyCache($key_type,$value_type))
{
    buf_chk_in(&cache.anythings);
}

anycache_remove_free_list :: proc(cache : ^AnyCache($key_type,$value_type),key : key_type) 
{
    assert(cache.is_using_free_list != false);
    index := hash_get(&cache.hash,key);
    buf_push(&cache.free_list,index);
    hash_remove(&cache.hash,key);
}

anycache_remove :: proc(cache : AnyCache($key_type,$value_type),key : key_type)
{
    assert(cache.is_using_free_list != false);
    hash_remove(&cache.hash,key);
}

anycache_chk_out_first_free :: proc(cache : ^AnyCache($key_type,$value_type)) -> ^key_type
{
    result : ^key_type = nil;
    if buf_len(cache.free_list) > 0
    {
        mi := buf_chk_out(&cache.free_list,buf_len(cache.free_list) - 1);
        assert(mi != nil);
        index := mi^;
        buf_chk_in(&cache.free_list);

        //checked out
        result := buf_chk_out(&cache.anythings,index);
        buf_pop(&cache.free_list);
    }
    return result;
}

/*
    anycache_chk_out_first_free_with_predicate(cache : ^AnyCache($key_type, $value_type),bool (*predicate)(void*))-> key_type
{
    void* result = 0;
    if(cache.free_list.fixed.count > 0)
    {
        umm* mi = fmj_stretch_buffer_check_out(umm,&cache.free_list,cache.free_list.fixed.count - 1);
        ASSERT(mi);
        u32 index = (u32)(*mi);
        fmj_stretch_buffer_check_in(&cache.free_list);
        
        result = fmj_stretch_buffer_checkout_ptr_(&cache.anythings,index);
        if(!predicate(result))
        {
            result = 0;
        }
        else
        {
            fmj_stretch_buffer_pop(&cache.free_list);
        }
    }
    return result;
}
*/
    
anycache_reset :: proc(cache : ^AnyCache($key_type,$value_type))
{
    buf_clear(&cache.anythings);
    buf_clear(&cache.free_list);
    //TODO(Ray): clear the hash.
    
//    buf_clear(&cache.hash.key_backing_array);
//    buf_clear(&cache.hash.keys);
//    buf_clear(&cache.hash.values);
//    buf_clear(&cache.hash.collisions);
//    buf_clear(&cache.hash.collision_free_list);
    //cache.hash.collision_count = 0;
}
