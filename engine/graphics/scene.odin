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
    matrix_buffer : Buffer(fmj.f4x4),
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

Transform :: struct 
{
//world trans    
    p : fmj.f3,
    r : fmj.quaternion,
    s : fmj.f3,
//local trans
    local_p : fmj.f3,    
    local_r : fmj.quaternion,
    local_s : fmj.f3,
//matrix
    m  : fmj.f4x4,
//local axis
    forward : fmj.f3,
    up : fmj.f3,
    right : fmj.f3,
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
    
    asset_tables.sprites = buf_init(1,Sprite);//fmj_stretch_buffer_init(1,sizeof(FMJSprite),8);
    asset_tables.textures = buf_init(1,Texture);//fmj_stretch_buffer_init(1,sizeof(LoadedTexture),8);    
    //NOTE(RAY):If we want to make this platform independendt we would just make a max size of all platofrms
    //struct and put in this and get out the opaque pointer and cast it to what we need.
    asset_tables.vertex_buffers = buf_init(1,D3D12_VERTEX_BUFFER_VIEW);//fmj_stretch_buffer_init(1,sizeof(D3D12_VERTEX_BUFFER_VIEW),8);
    asset_tables.index_buffers = buf_init(1,D3D12_INDEX_BUFFER_VIEW);//fmj_stretch_buffer_init(1,sizeof(D3D12_INDEX_BUFFER_VIEW),8);
    asset_tables.matrix_buffer = buf_init(1,fmj.f4x4);//fmj_stretch_buffer_init(1,sizeof(f4x4),8);

    asset_tables.meshes = buf_init(1,Mesh);//fmj_stretch_buffer_init(1,sizeof(FMJAssetMesh),8);
}

add_scene_object :: proc(ctx : ^AssetContext,sob : ^SceneObjectBuffer,p : fmj.f3,q : fmj.quaternion,s : fmj.f3,name : string)
{
    using fmj;
    
    assert(scene_objects != nil);
    assert(sob != nil);
    //fmj3dtransinit
    ot := transform_init();
    ot.p = p;
    ot.r = r;
    ot.s = s;
    
    new_so : SceneObject;//{name,ot,SceneObjectBuffer{},nil,nil,nil,f2{nil,nil};
    new_so.transform = ot;
    new_so.name = "default";
    new_so.m_id = buf_push(ctx.matrix_buffer,&ot.m);//buf_init(ctx.matrix_buffer,&ot.m);
    
    so_id := buf_push(ctx.scene_objects,new_so);
    buf_push(&sob.buffer,so_id);
}


