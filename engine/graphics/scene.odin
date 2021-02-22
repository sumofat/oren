package graphics;

import "core:fmt"
import "core:c"
import la "core:math/linalg"

import platform "../platform"
import fmj "../fmj"


AssetTables :: struct
{
    materials : map[string]RenderMaterial,
    material_count : u64,
    sprites : Buffer(Sprite),
    textures : Buffer(Texture),
    vertex_buffers : Buffer(platform.D3D12_VERTEX_BUFFER_VIEW),
    index_buffers : Buffer(platform.D3D12_INDEX_BUFFER_VIEW),
    matrix_buffer : Buffer(f4x4),
    meshes : Buffer(Mesh),
};

AssetContext :: struct
{
//    perm_mem : ^fmj.FMJMemoryArena,
//    temp_mem : ^fmj.FMJMemoryArena,
    asset_tables : AssetTables,
    scene_objects : Buffer(SceneObject),
    so_to_go : map[int]rawptr,//scene object to pointer of custom gameobject
};

Scene :: struct 
{
    name : string,
    buffer : SceneObjectBuffer,
    state_flags : SceneState    
};

SceneState :: enum
{
    default,//default state nothing happened
    loading,
    loaded,
    unloading,
    unloaded,
    serializing,
    serialized
};

SceneStatus :: struct
{
    state_flags : u32,
    object_count : u32,
};

SceneObjectBuffer :: struct
{
    buffer : Buffer(u64),
};

SceneObjectType :: enum
{
    mesh,
    light,
    model,
    camera,
};

SceneObject :: struct
{
    name : string,//for editor only
    transform : Transform,
    children : SceneObjectBuffer,
    m_id : u64,//matrix id refers to asset table matrix buffer
    type : u32,//user defined type
    data : rawptr,//user defined data typically ptr to a game object etcc...
    primitives_range : f2,
};

SceneObjectHandle :: Handle;

assetctx_init :: proc(ctx : ^AssetContext)
{
    using platform;
    ctx.scene_objects = buf_init(100,SceneObject);
    asset_tables := &ctx.asset_tables;
//    asset_tables.materials = ;//buf_init(100,RenderMaterial);//fmj_anycache_init(4096,sizeof(FMJRenderMaterial),sizeof(u64),true);
    
    asset_tables.sprites = buf_init(100,Sprite);
    asset_tables.textures = buf_init(100,Texture);

    asset_tables.vertex_buffers = buf_init(100,D3D12_VERTEX_BUFFER_VIEW);
    asset_tables.index_buffers = buf_init(100,D3D12_INDEX_BUFFER_VIEW);
    asset_tables.matrix_buffer = buf_init(100,f4x4);

    asset_tables.meshes = buf_init(100,Mesh);
}

scene_init :: proc(name : string) -> Scene
{
    a : Scene;
    a.name = name;
    a.buffer.buffer = buf_init(100,u64);
    a.state_flags = SceneState.default;
    return a;
}

scene_object_init :: proc(name : string) -> SceneObject
{
    a : SceneObject;
    ot := transform_init();
    
    a.transform = ot;
    a.name = name;
    a.children.buffer = buf_init(1,u64);
    return a;
}

scene_add_so :: proc(ctx : ^AssetContext,sob : ^SceneObjectBuffer,p : f3,q : Quat,s : f3,name : string) -> u64
{
    using fmj;
    assert(ctx != nil);
    assert(sob != nil);
    
    new_so := scene_object_init("New Scene Object");
    new_so.m_id = buf_push(&ctx.asset_tables.matrix_buffer,new_so.transform.m);
    new_so.transform.p = p;
    new_so.transform.r = q;
    new_so.transform.s = s;
    
    so_id := buf_push(&ctx.scene_objects,new_so);
    buf_push(&sob.buffer,so_id);
    return so_id;
}

//NOTE(Ray):When adding a chid ot p is local position and p is offset from parents ot p.
add_child_to_scene_object_with_transform :: proc(ctx : ^AssetContext,parent_so_id : u64,new_child : ^Transform,data : ^rawptr,name : string) -> u64
{
    assert(ctx != nil);
    assert(new_child != nil);
    //and the local p is the absolute p relative to the parent p.
    new_child.local_p = new_child.p;
    new_child.local_s = new_child.s;
    new_child.local_r = new_child.r;
    
    //New child p in this contex is the local p relative to the parent p reference frame
//		new_child->p  += rotate(so->transform.r, new_child->p);
    //Rotations add
//		new_child->r = so->transform.r * new_child->r;
//		new_child->s = so->transform.s * new_child->s;
    //SceneObject* new_so = AddSceneObject(&so->children, new_child);
    
    new_so : SceneObject;
    new_so.children.buffer = buf_init(1,u64);
    new_so.transform = new_child^;
    new_so.m_id = buf_push(&ctx.asset_tables.matrix_buffer,new_so.transform.m);
    new_so.name = name;
    //new_so.parent = so;
    if data != nil
    {
	new_so.data = data^;	
    }
    
    so_id := buf_push(&ctx.scene_objects,new_so);

    parent_so := buf_chk_out(&ctx.scene_objects,parent_so_id);
    if len(parent_so.children.buffer.buffer) == 0
    {
        parent_so.children.buffer = buf_init(1,u64);
    }
    
    buf_push(&parent_so.children.buffer,so_id);
    buf_chk_in(&ctx.scene_objects);
    
    return so_id;
}

//NOTE(Ray):When adding a chid ot p is local position and p is offset from parents ot p.
add_new_child_to_scene_object :: proc(ctx : ^AssetContext,parent_so_id : u64,p : f3,r : Quat,s : f3,data : ^rawptr,name : string) -> u64
{
    assert(ctx != nil);
    new_child := transform_init();
    new_child.p = p;
    new_child.r = r;
    new_child.s = s;
    transform_update(&new_child);
    return add_child_to_scene_object_with_transform(ctx,parent_so_id,&new_child,data,name);
}

add_child_to_scene_object :: proc(ctx : ^AssetContext,parent_so_id : u64,child_so_id : u64,transform : Transform)
{
    assert(ctx != nil);    
        //and the local p is the absolute p relative to the parent p.
    t := transform;
    t.local_p = transform.p;
    t.local_s = transform.s;
    t.local_r = transform.r;

    //get the model so
    child_so := buf_chk_out(&ctx.scene_objects,child_so_id);
    assert(child_so != nil);
    child_so.transform = t;
    buf_chk_in(&ctx.scene_objects);

    //Add this instance to the children of the parent so 
    parent := buf_chk_out(&ctx.scene_objects,parent_so_id);
    handle := buf_push(&parent.children.buffer,child_so_id);
    buf_chk_in(&ctx.scene_objects);
}

//NOTE(Ray):For updating all scenes?
update_scene :: proc(ctx : ^AssetContext,scene : ^Scene)
{
    assert(ctx != nil);    
    product := la.QUATERNION_IDENTITY;
    sum := f3{};
    update_scene_objects(ctx,&scene.buffer,&sum,&product);
}

update_scene_objects :: proc(ctx : ^AssetContext,buffer : ^SceneObjectBuffer, position_sum : ^f3, rotation_product : ^Quat)
{
    assert(ctx != nil);    
    for i := 0;i < cast(int)buf_len(buffer.buffer);i+=1
    {
        child_so_index := buf_chk_out(&buffer.buffer,cast(u64)i);        
        so := buf_chk_out(&ctx.scene_objects,child_so_index^);
        buf_chk_in(&buffer.buffer);
        parent_ot := &so.transform;
        transform_update(parent_ot);
        current_p_sum := position_sum^;
        current_p_sum = current_p_sum + parent_ot.p;
        rotation_product^ = la.quaternion_inverse(parent_ot.local_r);
        update_children(ctx,so, &current_p_sum, rotation_product);
        buf_chk_in(&ctx.scene_objects);
    }
}

update_children :: proc( ctx : ^AssetContext,parent_so : ^SceneObject,position_sum : ^f3,rotation_product : ^Quat)
{
    assert(ctx != nil);    
    child_so : ^SceneObject;
    for i := 0;i < cast(int)buf_len(parent_so.children.buffer);i+=1
    {
        child_so_index := buf_chk_out(&parent_so.children.buffer,cast(u64)i);
        child_so = buf_chk_out(&ctx.scene_objects,child_so_index^);        
        ot := &child_so.transform;
        current_p_sum := position_sum^;
        current_r_product := (rotation_product^);
	current_p_sum = current_p_sum + rotate(current_r_product,ot.local_p);
	ot.p = current_p_sum;
        ot.r = la.mul(current_r_product,ot.local_r);//(quaternion_mul(current_r_product,ot.local_r));
	current_r_product = ot.r;	
        
        ot.s = ot.local_s;//f3_mul(parent_so.transform.s,ot.local_s);//

        update_children(ctx,child_so, &current_p_sum, &current_r_product);
        buf_chk_in(&parent_so.children.buffer);
        buf_chk_in(&ctx.scene_objects);
    }
}
