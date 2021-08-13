package graphics

import math "core:math"
import la "core:math/linalg"

import platform "../platform"

init_pers_proj_matrix :: proc(buffer_dim : f2,fov_y : f32,far_near : f2) -> f4x4
{
    using math;
    near_clip_plane := far_near.x;
    far_clip_plane := far_near.y;
    tangent := tan(la.radians(fov_y / 2));
    aspect_ratio := buffer_dim.x / buffer_dim.y;
    z_depth_range := far_clip_plane - near_clip_plane;

    a := 1.0 / (tangent * aspect_ratio);
    b := 1.0 / tangent;
    z := -((far_clip_plane + near_clip_plane) / z_depth_range);
    z2 := -((2.0 * far_clip_plane * near_clip_plane) / z_depth_range);
    result := f4x4_create_row(a, b, z,0);

    result[2].w = -1;
    result[3].x = 0;
    result[3].y = 0;
    result[3].z = z2;
    return result;
}

init_ortho_proj_matrix :: proc(size : f2,near_clip_plane : f32,far_clip_plane : f32) -> f4x4 
{
    r := size.x;
    l := -r;
    t := size.y;
    b := -t;
    zero := 2.0 / (r - l);
    five := 2.0 / (t - b);
    ten := -2.0 / (far_clip_plane - near_clip_plane);

    result := f4x4_create_row(zero, five, ten,1);

    result[3].x = (-((r + l)  / (r - l)));
    result[3].y = (-((t + b)  / (t - b)));
    result[3].z = ( 0 );
    return result;
}

init_screen_space_matrix :: proc(buffer_dim : f2) -> f4x4 
{
    ab := 2.0 / buffer_dim;
    result := f4x4_create_row(ab.x, ab.y, 1,1);

    result[3].x = -1;
    result[3].y = -1;
    return result;
}
