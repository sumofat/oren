package graphics

import math "core:math"
import la "core:math/linalg"

import platform "../platform"
import enginemath "../math"
import con "../containers"


RenderCameraProjectionType :: enum {
    perspective,
    orthographic,
    screen_space,
}

RenderCamera :: struct {
    ot:                                   Transform, //perspective and ortho only
    m :                               enginemath.f4x4,
    projection_matrix:                    enginemath.f4x4,
    spot_light_shadow_projection_matrix:  enginemath.f4x4,
    point_light_shadow_projection_matrix: enginemath.f4x4,
    projection_type:                      RenderCameraProjectionType,
    size:                                 f32, //ortho only
    fov:                                  f32, //perspective only
    near_far_planes:                      enginemath.f2,
    matrix_id:                            u64,
    projection_matrix_id:                 u64,
    viewport : ^CameraViewport,
}

CameraViewport :: struct{

}

CameraSystem :: struct{
    cameras : con.Buffer(RenderCamera),
    viewports : con.Buffer(CameraViewport),
}

camera_system : CameraSystem

game_camera : ^RenderCamera

camera_system_add_camera :: proc(ot : Transform,cam_type : RenderCameraProjectionType){
    using platform
    
    rc : RenderCamera
    rc.ot = ot

    //aspect_ratio := ps.window.dim.x / ps.window.dim.y;
    //size := size * aspect_ratio;
    //    rc.projection_matrix = init_ortho_proj_matrix(size,0.0f,1.0f);
    rc.fov = 80;
    rc.near_far_planes = f2{0.1, 1000};
    if cam_type == .perspective{
        rc.projection_matrix = init_pers_proj_matrix(ps.window.dim, rc.fov, rc.near_far_planes);
    }else{
        assert(false)
    }
    
    rc.m = la.MATRIX4F32_IDENTITY;

    matrix_buffer        := &asset_ctx.asset_tables.matrix_buffer;
    rc.projection_matrix_id := buf_push(matrix_buffer, rc.projection_matrix);
    rc.matrix_id         := buf_push(matrix_buffer, rc.m);
}

camera_system_init :: proc(){
    camera_system.cameras = con.buf_init(0,RenderCamera)
    camera_system.viewports = con.buf_init(0,CameraViewport)

}

init_pers_proj_matrix :: proc(buffer_dim : enginemath.f2,fov_y : f32,far_near : enginemath.f2) -> enginemath.f4x4
{
    using math;
    using enginemath;
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

init_ortho_proj_matrix :: proc(size : enginemath.f2,near_clip_plane : f32,far_clip_plane : f32) -> enginemath.f4x4 
{
    r := size.x;
    l := -r;
    t := size.y;
    b := -t;
    zero := 2.0 / (r - l);
    five := 2.0 / (t - b);
    ten := -2.0 / (far_clip_plane - near_clip_plane);

    result := enginemath.f4x4_create_row(zero, five, ten,1);

    result[3].x = (-((r + l)  / (r - l)));
    result[3].y = (-((t + b)  / (t - b)));
    result[3].z = ( 0 );
    return result;
}

init_screen_space_matrix :: proc(buffer_dim : enginemath.f2) -> enginemath.f4x4 
{
    ab := 2.0 / buffer_dim;
    result := enginemath.f4x4_create_row(ab.x, ab.y, 1,1);

    result[3].x = -1;
    result[3].y = -1;
    return result;
}
