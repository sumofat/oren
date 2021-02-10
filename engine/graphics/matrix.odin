package graphics

import "core:fmt"
import "core:c"

import platform "../platform"
import fmj "../fmj"

f4x4_create_from_quaternion_translation(r : quaternion ,t : f3)-> f4x4
{
    f4x4 result = {0};
    f3x3 rot = f3x3_create_from_quaternion(r);
	result.c0 = f4_create(rot.c0.x,rot.c0.y,rot.c0.z,0.0f);
    result.c1 = f4_create(rot.c1.x,rot.c1.y,rot.c1.z,0.0f);
	result.c2 = f4_create(rot.c2.x,rot.c2.y,rot.c2.z,0.0f);
    result.c3 = f4_create(t.x,t.y,t.z,1.0f);
    return result;
}

f4x4_create_from_trs(t : f3,r : quaternion,s : f3) -> f4x4
{
    using fmj;
    rotation := f4x4_create_from_quaternion_translation(r,t);
    scale_matrix := f4x4_create_with_scale(s.x,s.y,s.z);
    return f4x4_mul(rotation,scale_matrix);
}
