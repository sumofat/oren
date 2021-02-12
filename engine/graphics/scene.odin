package graphics;

import "core:fmt"
import "core:c"

import platform "../platform"
import fmj "../fmj"


Texture :: struct
{
    texels : rawptr
    dim : fmj.f2,
    size : u32,
    bytes_per_pixel : u32,
    width_over_height : f32,// TODO(Ray Garner): probably remove
    align_percentage : fmj.f2,// TODO(Ray Garner): probably remove this
    channel_count : u32,//grey = 1: grey,alpha = 2,rgb = 3,rgba = 4
    //    Texture texture : Texture,
    state : rawptr,// NOTE(Ray Garner): temp addition
    slot : u32,
};

Sprite :: struct
{
    id : u64,
    tex_id : u32,
    uvs : [4]fmj.f2,
    color : fmj.f4,
    is_visible : bool,
    material_name : string,
};

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

FMJSceneObjectType :: enum
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
    primitives_range : fmj.f2,
};

SceneObjectHandle :: Handle;

assetctx_init :: proc(ctx : ^AssetContext)
{
    using platform;
    ctx.scene_objects = buf_init(1,SceneObject);
    asset_tables := &ctx.asset_tables;
//    asset_tables.materials = ;//buf_init(1,RenderMaterial);//fmj_anycache_init(4096,sizeof(FMJRenderMaterial),sizeof(u64),true);
    
    asset_tables.sprites = buf_init(1,Sprite);
    asset_tables.textures = buf_init(1,Texture);

    asset_tables.vertex_buffers = buf_init(1,D3D12_VERTEX_BUFFER_VIEW);
    asset_tables.index_buffers = buf_init(1,D3D12_INDEX_BUFFER_VIEW);
    asset_tables.matrix_buffer = buf_init(1,f4x4);

    asset_tables.meshes = buf_init(1,Mesh);
}

scene_init :: proc(name : string) -> Scene
{
    a : Scene;
    a.name = name;
    a.buffer.buffer = buf_init(1,u64);
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

