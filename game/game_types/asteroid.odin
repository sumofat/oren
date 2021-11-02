package game_types
import pkg_entity "../../engine/entity"
import con "../../engine/containers"
import e_math "../../engine/math"
import platform "../../engine/platform"

Asteroid :: struct{
	velocity : e_math.f3,
	speed : f32,
	max_speed : f32,
}

asteroid_array : con.Buffer(Asteroid)
asteroid_arch_id : pkg_entity.EntityBucketKey

update_ecs_asteroid :: proc(bucket : ^pkg_entity.EntityBucket,data : rawptr){
	using platform
	dt := ps.time.delta_seconds

	for e ,i in bucket.entities.buffer{
		asteroids := (^con.Buffer(Asteroid))(data)
		using asteroid := con.buf_ptr(asteroids,u64(i))
		using e := con.anycache_get_ptr(&pkg_entity.trs,e)
				
	}
}

init_asteroids :: proc(){
	asteroid_array = con.buf_init(1,Asteroid)
	ok : bool
	ok,asteroid_arch_id = pkg_entity.get_archetype([]typeid{typeid_of(Asteroid)},[]rawptr{rawptr(&asteroid_array)})
	pkg_entity.create_system(update_ecs_asteroid,asteroid_arch_id)
}

add_asteroid :: proc() -> ^Asteroid{
	using e_math
	using asteroid : Asteroid
	new_e := pkg_entity.create_entity(asteroid_arch_id)
	velocity = f3{0,0,0}
	speed = 0
	max_speed = 5
	
	t : pkg_entity.TRS
	t.p = f3{0,0,0}
	t.s = f3{1,1,1}
	t.r = quat_identity
	con.anycache_add(&pkg_entity.trs,new_e,t)
	id := con.buf_push(&asteroid_array,asteroid)
	return con.buf_ptr(&asteroid_array,id)
}

update_ecs_render :: proc(bucket : ^pkg_entity.EntityBucket,data : rawptr){

}