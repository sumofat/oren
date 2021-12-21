package entity
import con "../containers"
import e_math "../math"
import platform "../platform"
import logger "../logger"
import ocon "core:container"
//import gfx "../graphics"

Entity :: distinct u64
TRS :: struct{
	p : e_math.f3,
	r : e_math.Quat,
	s : e_math.f3,
}

trs : con.AnyCache(Entity,TRS)

type_as_int :: proc(t : $T) -> int{
	return transmute(int)(typeid_of(type_of(t)))
}

/*
type_set :: bit_set[0..127]
ts : type_set

tes :: proc(l : Lantern_Ent){
	ts : type_set = {type_as_int(l)}
}
*/

	
ComponentSet :: struct{
	key : EntityBucketKey,
	components : con.Buffer(EntityComponent),
}

EntitySystem :: struct{
	update : proc(bucket : ^EntityBucket,data : rawptr),
	bucket_key : EntityBucketKey,
}

EntityComponent :: struct{
	t : typeid,
	data : rawptr,
}

EntityBucket :: struct{
	entities : con.Buffer(Entity),
	components : con.Buffer(EntityComponent),
}

EntityBucketKey :: struct{
	key : EntityArchetypeID,
	tag : u64,
}

entity_buckets : con.AnyCache(EntityBucketKey,EntityBucket)
MAX_ARCHETYPE_COUNT :: 300

init_buckets :: proc(){
	entity_buckets = con.anycache_init(EntityBucketKey,EntityBucket,false)
}

EntityComponentID :: distinct u64
EntityArchetypeID :: distinct u64
current_archetype_id : u64
current_entity_id : u64//0 based
systems : con.Buffer(EntitySystem)
component_set : con.Buffer(ComponentSet)

entity_components :: con.Buffer(u64)

types_dyn : [dynamic]typeid

//For removal its either create a free list (use anycahce free list) 
//or do array flattening with memcpy/set  would depend on how large the holes were in the array
//etc.. for nwo we carry on and revisit this when we need removal
init_ecs :: proc(){
	systems = con.buf_init(1,EntitySystem)
	component_set = con.buf_init(1,ComponentSet)
	trs = con.anycache_init(Entity,TRS,false)
	
}

update_ecs_entities :: proc(){
	key : EntityBucketKey
	for s ,i in systems.buffer{
		if s.update != nil{
			bucket := retrieve_bucket(s.bucket_key)
			if bucket != nil{
				ec := con.buf_get(&bucket.components,0)
				s.update(bucket,ec.data)
				//logger.print_log("excute system : ",bucket)
			}
		}
	}
}

retrieve_bucket :: proc(key : EntityBucketKey) -> ^EntityBucket{
	add_bucket(key)		
	bucket := con.anycache_get_ptr(&entity_buckets,key)
	if bucket == nil{
		assert(false)
	}
	return bucket
}

get_bucket :: proc(key : EntityBucketKey) -> ^EntityBucket{
	using con
	if anycache_exist(&entity_buckets,key){
		return anycache_get_ptr(&entity_buckets,key)
	}else{
		//some error handling
		return nil
	}
}

add_bucket :: proc(key : EntityBucketKey) -> (bool){
	//using con
	if !con.anycache_exist(&entity_buckets,key){

		b : EntityBucket
		b.entities = con.buf_init(1,Entity)
		return con.anycache_add(&entity_buckets,key,b)
	}else{
		return false
	}
}

add_component_to_bucket :: proc(bucket : ^EntityBucket,comp : EntityComponent){
	con.buf_push(&bucket.components,comp)
}

add_archetype :: proc(tag : u64) -> EntityBucketKey{
	result : EntityBucketKey
	result.key = EntityArchetypeID(current_archetype_id)
	result.tag = tag
	current_archetype_id += 1
	return result
}


create_entity :: proc(key : EntityBucketKey) -> Entity{
	using con
	new_e := Entity(current_entity_id)

	add_bucket(key)
	bucket := get_bucket(key)
	if bucket != nil{
		//anycache_add(&,key,new_e)
		buf_push(&bucket.entities,new_e)
		current_entity_id += 1
	}else{
		//error
		assert(false)
	}
	return new_e
}

get_archetype :: proc(types : []typeid,data : []rawptr,tag : u64 = 0)-> (is_new_id : bool,arch_id : EntityBucketKey){
	//search for same component combination
	true_set : ComponentSet
	for s in component_set.buffer{//buckets

		for c in s.components.buffer{//components in buckets
			is_in_set : bool = false

			for t in types{//types we want to add
				if t != c.t{//if one type is  not equal to the component
					is_in_set = true
				}
			}
			//if the tags are equal than than continue if the tag is different create a new bucket
			if is_in_set == false && s.key.tag == tag{
				return false,s.key//EntityBucketKey{s.keyid,tag}
			}
		}

	 
	}

	//No component set found create a new bucket and archetype
	new_arch_id := add_archetype(tag)

	//add bucket for that 
	add_bucket(new_arch_id)
	new_bucket := get_bucket(new_arch_id)
	//logger.print_log(new_bucket)

	new_comp_set : ComponentSet
	new_comp_set.key = new_arch_id
	new_comp_set.components = con.buf_init(u64(len(types)),EntityComponent)
	for t ,i in types{
		new_comp : EntityComponent
		new_comp.t = t//types
		new_comp.data = data[i]
		add_component_to_bucket(new_bucket,new_comp)
		con.buf_push(&new_comp_set.components,new_comp)
	}
	con.buf_push(&component_set,new_comp_set)
	return true,new_arch_id
}

create_system :: proc(update : proc(bucket : ^EntityBucket,data : rawptr),arch_id : EntityBucketKey){
	system : EntitySystem
	system.update = update
	system.bucket_key = arch_id
	con.buf_push(&systems,system)
}

	/*




Entities :: struct{
	using entity_buffer : EntityBuffer,
	using entity_actions : EntityActionsBuffer,
	types : con.Hash(Entity,typeid),
}

	

init_entities :: proc() -> Entities{
	result : Entities
	trs =  con.anycache_init(Entity,TRS,false)
	//ALl entities
	result.entity_buffer.entities = con.buf_init(1000,Entity)
	//all possible updates on entities
	//result.actions  = con.buf_init(100,EntityAction)
	result.entity_actions.actions = con.hash_init(typeid,EntityAction)
	return result
}
add_entity_type :: proc(es : ^Entities,$type : typeid,update_proc : proc(e:Entity,data:rawptr)){
	ea : EntityAction
	ea.update = update_proc
	if !con.hash_exist(&es.entity_actions.actions,type){
		con.hash_add(&es.entity_actions.actions,type,ea)
	}
}














EntityBuffer :: struct{
	entities : con.Buffer(Entity),
}

EntityAction :: struct{
	update : proc(e : Entity,data  : rawptr),
}

EntityActionsBuffer :: struct{
	actions : con.Hash(typeid,EntityAction),
}




add_entity ::proc(es : ^Entities,id : u64,$type : typeid) -> Entity{
	e : Entity = Entity(id)
	i := con.buf_push(&es.entities,e)
	if !con.hash_exist(&es.types,e){
		con.hash_add(&es.types,e,type)
	}
	return con.buf_get(&es.entities,i)
}


update_entities :: proc(es : ^Entities){
	for e, i in &es.entities.buffer{
		type_id := con.hash_get(&es.types,e)
		action := con.hash_get(&es.actions,type_id)//con.buf_get(&es.actions,u64(i))
		action.update(e,nil)
	}
}
*/
update_ecs_lantern :: proc(bucket : ^EntityBucket,data : rawptr){
	using platform
	for e,i in bucket.entities.buffer{
		
		ecs_lanterns := (^con.Buffer(Lantern_Ent))(data)
		//using lantern := (^Lantern_Ent)(data)
	//	using lantern := con.anycache_get_ptr(&lanterns,entity)//lanterns[u64(entity)]//(^Entity(Lantern_Ent))(entity)
		using lantern := con.buf_ptr(ecs_lanterns,u64(i))//lanterns[u64(entity)]
		using e := con.anycache_get_ptr(&trs,e)//con.buf_get(&trs,u64(entity))

		if e.p.x > 4{
			dir = -1;
		}else if e.p.x < -4{
			dir = 1;
		}	

		if e.p.z < -10{
			ydir = 1;
		}else if e.p.z > -6{
			ydir = -1
		}
	 	dt := ps.time.delta_seconds
		e.p.x += speed * dir * dt
		e.p.z += yspeed * ydir * dt
		//logger.print_log(e)
		
		//t := gfx.get_t(so_id);
		//t.local_p.x = e.p.x//+= speed * dir * dt;
		//t.local_p.z = e.p.z//yspeed * ydir * dt;
	}
}

add_lantern_ecs :: proc(scene_object_id : u64)-> ^Lantern_Ent{
	using e_math
	using lantern : Lantern_Ent


		//add_component_to_bucket(bucket,new_comp)

		//add entity lantern example
	new_e := create_entity(lantern_arch_id)

	dir = 1
	ydir = 1	
	speed = 10
	yspeed = 1
	so_id = scene_object_id

	t : TRS
	t.p = f3{0,0,0}
	t.s = f3{1,1,1}
	t.r = quat_identity
	
	index  := con.buf_push(&lanterns,lantern)
	//new_entity := add_entity(es,index,Lantern_Ent)
	//con.anycache_add(&lanterns,new_entity,lantern)
	con.anycache_add(&trs,new_e,t)
	return con.buf_ptr(&lanterns,u64(new_e))
}
Lantern_Ent :: struct{
	speed : f32,
	yspeed : f32,
	dir : f32,
	ydir : f32,
	so_id : u64,
}

lanterns : con.Buffer(Lantern_Ent)
lantern_arch_id :  EntityBucketKey
init_lantern :: proc(){
	lanterns = con.buf_init(1,Lantern_Ent)

	ok,arch_id := get_archetype([]typeid{typeid_of(Lantern_Ent)},[]rawptr{rawptr(&lanterns)})
	lantern_arch_id  =  arch_id
	create_system(update_ecs_lantern,arch_id)


}

/*


//lanterns : con.AnyCache(Entity,Lantern_Ent)


update_lantern :: proc(entity : Entity,data : rawptr){
	using platform
	//using lantern := (^Lantern_Ent)(data)
//	using lantern := con.anycache_get_ptr(&lanterns,entity)//lanterns[u64(entity)]//(^Entity(Lantern_Ent))(entity)
	using lantern := con.buf_ptr(&lanterns,u64(entity))//lanterns[u64(entity)]
	using e := con.anycache_get_ptr(&trs,entity)//con.buf_get(&trs,u64(entity))

	if e.p.x > 4{
		dir = -1;
	}	
	else if e.p.x < -4{
		dir = 1;
	}	

	if e.p.z < -10{
		ydir = 1;
	}
	else if e.p.z > -6{
		ydir = -1
	}
 	dt := ps.time.delta_seconds
	e.p.x += speed * dir * dt
	e.p.z += yspeed * ydir * dt
	logger.print_log(e)
}

add_lantern :: proc(es : ^Entities)-> ^Lantern_Ent{
	using e_math
	using lantern : Lantern_Ent
	dir = 1
	ydir = 1	
	speed = 10
	yspeed = 1
	
	t : TRS
	t.p = f3{0,0,0}
	t.s = f3{1,1,1}
	t.r = quat_identity
	
	index  := con.buf_push(&lanterns,lantern)
	new_entity := add_entity(es,index,Lantern_Ent)
	//con.anycache_add(&lanterns,new_entity,lantern)
	con.anycache_add(&trs,new_entity,t)
	return con.buf_ptr(&lanterns,u64(new_entity))
}

*/


/*
notion of an entity is such that its just concept for systems to do data on
that can be used in a way that is performant or flexibility based.



EntityBuffer :: struct(type : typeid){
	entities : con.Buffer(Entity(type)),

}

TRS :: struct{
	p : e_math.f3,
	r : e_math.Quat,
	s : e_math.f3,
}

Entity :: struct(type : typeid){
	using t : TRS,
	using sub_type : type,
}

EntityAction :: struct(type : typeid){
	data : rawptr,	
	update : proc(e : rawptr,data  : rawptr),
}

EntityActionsBuffer :: struct(type : typeid){
	actions : con.Buffer(EntityAction(type)),
}

Entities :: struct(type : typeid){
	using entity_buffer : EntityBuffer(type),
	using entity_actions : EntityActionsBuffer(type),
}

EntityMaster :: struct{
	 buffer : con.Buffer(rawptr),
}

init_entities :: proc($T : typeid) -> Entities(T){
	result : Entities(T)

	result.entities = con.buf_init(1000,Entity(T))
	result.actions  = con.buf_init(1000,EntityAction(T))

	return result
}

add_entity :: proc(es : ^Entities($T),update_proc : proc(e:rawptr,data:rawptr)) -> ^Entity(T){
	e : Entity(T)
	ea : EntityAction(T)
	ea.update = update_proc
	id := con.buf_push(&es.entities,e)
	con.buf_push(&es.actions,ea)
	return con.buf_ptr(&es.entities,id)
}

update_entities :: proc(es : ^Entities($T)){
	for e, i in &es.entities.buffer{
		action := con.buf_get(&es.actions,u64(i))
		action.update(&e,action.data)
	}
}

//TEst example entity
Lantern_Ent :: struct{
	speed : f32,
	yspeed : f32,
	dir : f32,
	ydir : f32,
}
/*
init_lantern :: proc(e : ^Entity($T),data : rawptr){
	using lantern := (^Lantern_Ent)(data)
	using e_math
	dir = 1
	ydir = 1	
	speed = 10
	yspeed = 1

	e.p = f3{0,0,0}
	e.s = f3{1,1,1}
	e.r = quat_identity
}
*/

init_lantern :: proc()-> Entity(Lantern_Ent){
	using e_math

	using e : Entity(Lantern_Ent)
	dir = 1
	ydir = 1	
	speed = 10
	yspeed = 1

	e.p = f3{0,0,0}
	e.s = f3{1,1,1}
	e.r = quat_identity
	return e
}

update_lantern :: proc(entity : rawptr,data : rawptr){
	using platform
	//using lantern := (^Lantern_Ent)(data)
	using e := (^Entity(Lantern_Ent))(entity)
	if e.p.x > 4{
		dir = -1;
	}	
	else if e.p.x < -4{
		dir = 1;
	}	

	if e.p.z < -10{
		ydir = 1;
	}
	else if e.p.z > -6{
		ydir = -1
	}
 	dt := ps.time.delta_seconds
	e.p.x += speed * dir * dt
	e.p.z += yspeed * ydir * dt
	logger.print_log(e)
}
*/
