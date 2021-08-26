package graphics

import "core:fmt"
import "core:c"
import "core:mem"
import "core:math"

import platform "../platform"

import la "core:math/linalg"

import con "../containers";
import enginemath "../math"

Light :: struct
{
    p : enginemath.f3,
    color : enginemath.f4,
    size : f32,
    intensity : f32,
};

ShaderLight :: struct
{
    p : enginemath.f4,
    color : enginemath.f4,
    size_intensity : enginemath.f4,
    padding : enginemath.f4,
};

add_light_to_scene :: proc(scene : ^Scene,light : Light)
{
    con.buf_push(&scene.lights,light);
    
}

add_light_to_scene_with_properties :: proc(scene : ^Scene,p : enginemath.f3,color : enginemath.f4 = enginemath.f4{1,1,1,1},size : f32 = 1,intensity : f32 = 1)
{
    light : Light = {p,color,size,intensity}; 
    con.buf_push(&scene.lights,light);
}

add_light :: proc{add_light_to_scene,add_light_to_scene_with_properties};


