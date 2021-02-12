package graphics

import "core:fmt"
import "core:c"
import la "core:math/linalg"

import platform "../platform"

f4 :: la.Vector4;
f3 :: la.Vector3;
f2 :: la.Vector2;

f4x4 :: la.Matrix4x4;
Quat :: la.Quaternion;

screen_to_world :: proc(projection_matrix : f4x4,cam_matrix : f4x4,buffer_dim : f2,screen_xy :  f2,z_depth :  f32) -> f3
{
    using la;
    result : f3;

    pc_mat := mul(projection_matrix,cam_matrix);
    inv_pc_mat := transpose(matrix4_inverse(pc_mat));
    p := f4{
        2.0 * screen_xy.x / buffer_dim.x - 1.0,
        2.0 * screen_xy.y / buffer_dim.y - 1.0,
        z_depth,
        1.0
    };

    w_div := matrix_mul_vector(inv_pc_mat,p);

    f3_w_div := f3{w_div.x,w_div.y,w_div.z};
    //    w := safe_ratio_zero(1.0f, w_div.w);
    w := 1 / w_div.w;

    return f3_w_div * w;
}
