package graphics

import "core:fmt"
import "core:c"
import "core:mem"
import "core:math"

import platform "../platform"

import la "core:math/linalg"

import con "../containers";

Light :: struct
{
    p : f3,
    color : f4,
    size : f32,
    intensity : f32,
};

add_light_to_scene :: proc(scene : ^Scene,light : Light)
{
    con.buf_push(&scene.lights,light);
    
}

add_light_to_scene_with_properties :: proc(scene : ^Scene,p : f3,color : f4 = f4{1,1,1,1},size : f32 = 1,intensity : f32 = 1)
{
    light : Light = {p,color,size,intensity}; 
    con.buf_push(&scene.lights,light);
}

add_light :: proc{add_light_to_scene,add_light_to_scene_with_properties};


