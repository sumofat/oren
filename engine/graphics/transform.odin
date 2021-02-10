package graphics;

import "core:fmt"
import "core:c"

import platform "../platform"
import fmj "../fmj"


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

transform_init() -> Transform
{
    ot.r = quaternion_identity();
    ot.s = f3_create(1,1,1);
    ot.p = f3_create(0,0,0);
    ot.local_r = quaternion_identity();
    ot.local_s = f3_create(1,1,1);
    ot.local_p = f3_create(0,0,0);
    fmj_3dtrans_update(ot);
}

fmj_3dtrans_matrix_set(ot : ^Transform)
{
    ot.m = f4x4_create_from_trs(ot.p,ot.r,ot.s);
}

transform_update(ot : ^Transform)
{
    transform_matrix_set(ot);
    ot.up = quaternion_up(ot.r); 
    ot.right = quaternion_right(ot.r);
    ot.forward = quaternion_forward(ot.r);
}

