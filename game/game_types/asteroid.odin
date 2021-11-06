package game_types
import pkg_entity "../../engine/entity"
import con "../../engine/containers"
import e_math "../../engine/math"
import platform "../../engine/platform"
import gfx "../../engine/graphics"
import linalg "core:math/linalg"
import logger "../../engine/logger"
Asteroid :: struct{
	id : u64,
	velocity : e_math.f3,
	speed : f32,
	max_speed : f32,
	sprite_id : u64,
	layer_buffer_id : u64,
}

asteroid_array : con.Buffer(Asteroid)
asteroid_arch_id : pkg_entity.EntityBucketKey
global_sprite_id :  u64
cur_deg : f32
layer : ^gfx.SpriteLayer

update_sprite :: proc(using sprite : gfx.Sprite,using asteroid : Asteroid,using t : ^pkg_entity.TRS){
	using e_math
	using gfx.asset_ctx
	using platform.ps

	sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)
	new_r := linalg.quaternion_angle_axis(linalg.radians(cur_deg),f3{0,0,1})
		
	//logger.print_log("asteroid update_sprite P : ",p)
	//logger.print_log("asteroid update_sprite Velocity : ",sprite_id,velocity)
	p += velocity * time.delta_seconds//f3{0.01,0,0}
	r = new_r//linalg.mul(new_r,r)
	mat := con.buf_get(&asset_tables.matrix_buffer,u64(proj_id))
	sprite_matrix^ = linalg.matrix_mul(mat,linalg.matrix4_from_trs(p,r,s))


}

update_ecs_asteroid :: proc(bucket : ^pkg_entity.EntityBucket,data : rawptr){
	using platform
		using platform.ps

	dt := ps.time.delta_seconds

	for e ,i in bucket.entities.buffer{
		using e_math
		asteroids := (^con.Buffer(Asteroid))(data)
		using asteroid := con.buf_ptr(asteroids,u64(i))
		using t := con.anycache_get_ptr(&pkg_entity.trs,e)
		using gfx.asset_ctx
		sprite := con.buf_get(&gfx.sprite_buffers[layer_buffer_id],sprite_id)
		//logger.print_log("asteroid update_sprite EntityID : ",e)
		//logger.print_log("asteroid update_sprite AsteroidID : ",id)
		//logger.print_log("asteroid update_sprite SpriteID : ",sprite_id)
		//logger.print_log("asteroid update_sprite : ",sprite_id,sprite)

		update_sprite(sprite,asteroid^,t)
	}
	cur_deg += 20 * time.delta_seconds

}

init_asteroids :: proc(){
	using e_math
	asteroid_array = con.buf_init(1,Asteroid)
	ok : bool
	ok,asteroid_arch_id = pkg_entity.get_archetype([]typeid{typeid_of(Asteroid)},[]rawptr{rawptr(&asteroid_array)})
	pkg_entity.create_system(update_ecs_asteroid,asteroid_arch_id)
	p := f3{0,0,0}
	s := f3{1,1,1}
	r := quat_identity
}

add_asteroid :: proc(layer : ^gfx.SpriteLayer,p : e_math.f3,r : e_math.Quat,s : e_math.f3,initial_velocity : e_math.f3) -> ^Asteroid{
	using e_math
	using gfx
	using asteroid : Asteroid
	new_e := pkg_entity.create_entity(asteroid_arch_id)
	velocity = initial_velocity//f3{0,0,0}
	speed = 0
	max_speed = 5
	
	t : pkg_entity.TRS
	t.p = p//f3{0,0,0}
	t.s = s//f3{1,1,1}
	t.r = r//quat_identity
	con.anycache_add(&pkg_entity.trs,new_e,t)

	sprite_id = gfx.add_sprite(layer,p,r,s)
	if layer == nil{
		layer_buffer_id = 0
	}else{
		layer_buffer_id = layer.buffer_id
	}
	asteroid.id = con.buf_len(asteroid_array)
	con.buf_push(&asteroid_array,asteroid)
	
	return con.buf_ptr(&asteroid_array,id)
}
