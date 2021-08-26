package graphics;

import "core:fmt"
import "core:c"

import platform "../platform"
import fmj "../fmj"

import "core:math"
import la "core:math/linalg"
import enginemath "../math"

Transform :: struct 
{
//world trans    
    p : enginemath.f3,
    r : enginemath.Quat,
    s : enginemath.f3,
//local trans
    local_p : enginemath.f3,    
    local_r : enginemath.Quat,
    local_s : enginemath.f3,
//matrix
    m  : enginemath.f4x4,
//local axis
    forward : enginemath.f3,
    up : enginemath.f3,
    right : enginemath.f3,
};

transform_init :: proc() -> Transform
{
    using la;
    ot : Transform;
    ot.r = QUATERNIONF32_IDENTITY;
    ot.s = enginemath.f3{1,1,1};
    ot.p = enginemath.f3{0,0,0};
    ot.local_r = QUATERNIONF32_IDENTITY;
    ot.local_s = enginemath.f3{1,1,1};
    ot.local_p = enginemath.f3{0,0,0};
    transform_update(&ot);
    return ot;
}

transform_matrix_set :: proc(ot : ^Transform)
{
    ot.m = la.matrix4_from_trs(ot.p,ot.r,ot.s);
}

quaternion_up :: proc(q : enginemath.Quat) -> enginemath.f3
{
    a := la.quaternion_mul_vector3(q, enginemath.f3{0, 1, 0});
    return la.vector_normalize(a);
}

quaternion_forward :: proc(q : enginemath.Quat) -> enginemath.f3
{
    using la;
    return vector_normalize(mul(q, enginemath.f3{0, 0, 1}));
}

quaternion_right :: proc(q : enginemath.Quat) -> enginemath.f3
{
    using la;
    return vector_normalize(mul(q, enginemath.f3{1, 0, 0}));
}

transform_update :: proc(ot : ^Transform)
{
    transform_matrix_set(ot);
    ot.up = quaternion_up(ot.r); 
    ot.right = quaternion_right(ot.r);
    ot.forward = quaternion_forward(ot.r);
}

