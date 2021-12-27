package graphics

import math "core:math"
import la "core:math/linalg"

import platform "../platform"
import enginemath "../math"
import con "../containers"
import fmt "core:fmt"

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
    used : bool,

    //movement
    cam_pitch_yaw_radians : enginemath.f2,
}

CameraViewport :: struct{
    rt_cpu_handle : platform.D3D12_CPU_DESCRIPTOR_HANDLE,
    srv_gpu_handle : platform.D3D12_GPU_DESCRIPTOR_HANDLE,
    resource_id : u64,
    used : bool,
}

CameraFreeList :: struct{
    cam : con.Buffer(u64),
    vp : con.Buffer(u64),
}

CameraSystem :: struct{
    cameras : con.Buffer(RenderCamera),
    viewports : con.Buffer(CameraViewport),
    free_list : CameraFreeList,
    next_free_id : int,
}
@private
camera_system : CameraSystem

get_camera :: proc(cam_id : u64)-> RenderCamera{
    using con
    assert(buf_len(camera_system.cameras) > 0)
    return buf_get(&camera_system.cameras,cam_id)
}

chk_out_camera :: proc(cam_id : u64)-> ^RenderCamera{
    using con
    assert(buf_len(camera_system.cameras) > 0)
    return buf_chk_out(&camera_system.cameras,cam_id)
}

chk_in_camera :: proc(){
    using con
    buf_chk_in(&camera_system.cameras)
}

get_cameras :: proc()-> con.Buffer(RenderCamera){return camera_system.cameras}

camera_system_add_camera :: proc(ot : Transform,cam_type : RenderCameraProjectionType) -> u64{
    using platform
    using enginemath
    using con

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
    rc.projection_matrix_id = buf_push(matrix_buffer, rc.projection_matrix);
    rc.matrix_id         = buf_push(matrix_buffer, rc.m);
    idx := buf_push(&camera_system.cameras,rc)
    return idx//buf_ptr(&camera_system.cameras,idx)
}

camera_add_viewport :: proc(cam_id : u64){
    using platform
    using con

    cam := buf_ptr(&camera_system.cameras,cam_id)
    assert(cam.viewport == nil)

    rt_gpu_heap_idx,srv_heap_idx,resource_id := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap)
    rt_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_render_target(device,render_texture_heap.value,rt_gpu_heap_idx)
    srv_gpu_handle : D3D12_GPU_DESCRIPTOR_HANDLE = get_gpu_handle_srv(device,default_srv_desc_heap.heap.value,2)

    new_viewport : CameraViewport
    new_viewport.rt_cpu_handle = rt_cpu_handle
    new_viewport.srv_gpu_handle = srv_gpu_handle
    fmt.tprintf("cpu handle : %v , gpu handle %v ",rt_cpu_handle,srv_gpu_handle)
    new_viewport.resource_id = resource_id
    idx := buf_push(&camera_system.viewports,new_viewport)
    cam.viewport = buf_ptr(&camera_system.viewports,idx)
}

camera_system_init :: proc(start_cap : u64){
    camera_system.cameras = con.buf_init(start_cap,RenderCamera)
    camera_system.viewports = con.buf_init(start_cap,CameraViewport)

    camera_system.free_list.cam = con.buf_init(start_cap,u64)
    camera_system.free_list.vp = con.buf_init(start_cap,u64)
}

remove_camera :: proc(id : u64){
    using camera_system
    using con
    c := buf_ptr(&cameras,id)
    c.viewport.used = false
    c.used = false

    buf_push(&free_list.cam,id)
    buf_push(&free_list.vp,id)

    buf_pop(&cameras)

    for cam,i in cameras.buffer{
        if cam.used == false{
            next_free_id = i
            break
        }
    }
}

camera_free :: proc(cam_id : u64,input : platform.Input,delta_seconds : f32){
    using enginemath
    using platform
    using la
    using con

    move_speed : f32 = 20.0
    move_dir := f3{}
    rc := chk_out_camera(cam_id)

    transform_update(&rc.ot)

    if input.keyboard.keys[keys.i].down{
        move_dir = move_dir + rc.ot.forward
    }
    if input.keyboard.keys[keys.k].down{
        move_dir = move_dir + (rc.ot.forward * -1)
    }
    if input.keyboard.keys[keys.j].down{
        move_dir = move_dir + rc.ot.right
    }
    if input.keyboard.keys[keys.l].down{
        move_dir = move_dir + (rc.ot.right * -1)
    }

    rc.ot.p = rc.ot.p + ((move_dir * -1) * move_speed * delta_seconds)
    //TODO(Ray):Convert delta p to an acceptable radian value based on angle per some time value?
    rc.cam_pitch_yaw_radians.x += radians(input.mouse.delta_p.x) * 0.5
    rc.cam_pitch_yaw_radians.y += radians(input.mouse.delta_p.y) * 0.5
    pitch := quaternion_angle_axis(rc.cam_pitch_yaw_radians.y * -1, f3{1, 0, 0})
    yaw   := quaternion_angle_axis(rc.cam_pitch_yaw_radians.x * -1, f3{0, 1, 0})
    turn_qt := pitch * yaw;
    rc.ot.r = turn_qt;

    rc.m = set_camera_view(&rc.ot)
    rc_mat := buf_chk_out(&asset_ctx.asset_tables.matrix_buffer,rc.matrix_id)
    rc_mat^ = rc.m
    buf_chk_in(&asset_ctx.asset_tables.matrix_buffer)
    chk_in_camera()
}


camera_chase :: proc(cam_id : u64,input : platform.Input ,delta_seconds : f32 ,target_ : Transform ,offset : enginemath.f3 )
{
    using enginemath
    using con
    rc := chk_out_camera(cam_id)
    target := target_
    transform_update(&target);
    transform_update(&rc.ot);
    t_p := target.p;
    n_f := -(target.forward);
    
    target_f := (n_f * 3);
    target_f = (target_f + offset);
    p := (t_p + target_f);
    f := target.forward;
    look_point_world := (t_p + f);
    cam_dir := (p - look_point_world);

    
    rc.ot.p = p;
    rc.ot.r = la.quaternion_look_at(p,look_point_world,f3{0,1,0});
    
    rc.m = set_camera_view(&rc.ot);
    rc_mat := buf_chk_out(&asset_ctx.asset_tables.matrix_buffer,rc.matrix_id);
    rc_mat^ = rc.m
    chk_in_camera()
}

camera_orbit :: proc(cam_id : u64,input : platform.Input,delta_seconds : f32 ,target : Transform,radius : f32){
    using enginemath
    using con
    using la

    rc := chk_out_camera(cam_id)
    transform_update(&rc.ot);
    rc.cam_pitch_yaw_radians.x += radians(input.mouse.delta_p.x) * 0.5
    rc.cam_pitch_yaw_radians.y += radians(input.mouse.delta_p.y) * 0.5
    pitch := quaternion_angle_axis(rc.cam_pitch_yaw_radians.y * -1,f3{1, 0, 0})
    yaw   := quaternion_angle_axis(rc.cam_pitch_yaw_radians.x * -1,f3{0, 1, 0})
    turn_qt := (pitch * yaw);        

    rc.ot.p = (target.p + (quaternion_forward(turn_qt) * radius));
    rc.ot.r = turn_qt;
    
    rc.m = set_camera_view(&rc.ot)
    rc_mat := buf_chk_out(&asset_ctx.asset_tables.matrix_buffer,rc.matrix_id);
    rc_mat^ = rc.m
    buf_chk_in(&asset_ctx.asset_tables.matrix_buffer)
    chk_in_camera()
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
