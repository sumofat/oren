package graphics
import platform "../platform"
import con "../containers"
import enginemath "../math"


render_commands:      con.Buffer(D12RenderCommand);
//render_commands_ptr:  ^RenderCommandList(GeometryRenderCommandList);
//render_command_lists: con.Buffer(RenderCommandList(GeometryRenderCommandList));

RenderCommand :: struct {
	geometry:              RenderGeometry,
	material_id:           u64,
	model_matrix_id:       u64,
	camera_matrix_id:      u64,
	perspective_matrix_id: u64,

	//TODO(Ray):Create a mapping between pipeline state root sig slots..
	//and inputs from the application ie textures buffers etc..
	//for now we just throw on the simple ones we are using now. 
	texture_id:            u64,
	is_indexed:            bool,
	material_name:         string,
}

LightRenderCommand :: struct{
    light : Light,
    using render_command : RenderCommand,
}

GeometryRenderCommandList :: struct {
	command_buffer : con.Buffer(RenderCommand),
}

LightRenderCommandList :: struct{
    command_buffer : con.Buffer(LightRenderCommand),
}

RenderCommandList :: struct($list_type: typeid) {
	list : list_type,
}

RenderProjectionPass :: struct {
	matrix_buffer:      ^con.Buffer(enginemath.f4x4),
	matrix_quad_buffer: ^con.Buffer(enginemath.f4x4),
	root_sig:           rawptr,
}

GbufferPass :: struct {
	matrix_buffer:      ^con.Buffer(enginemath.f4x4),
	matrix_quad_buffer: ^con.Buffer(enginemath.f4x4),
	root_sig:           rawptr,
	render_targets:     con.Buffer(platform.D3D12_CPU_DESCRIPTOR_HANDLE),
	shader:             RenderShader,
}

LightingAccumPass1 :: struct {
	matrix_buffer:      ^con.Buffer(enginemath.f4x4),
	matrix_quad_buffer: ^con.Buffer(enginemath.f4x4),
	root_sig:           rawptr,
	render_targets:     con.Buffer(platform.D3D12_CPU_DESCRIPTOR_HANDLE),
	shader:             RenderShader,
}

LightingAccumPass2 :: struct {
	matrix_buffer:          ^con.Buffer(enginemath.f4x4),
	matrix_quad_buffer:     ^con.Buffer(enginemath.f4x4),
	root_sig:               rawptr,
	render_targets:         con.Buffer(platform.D3D12_CPU_DESCRIPTOR_HANDLE),
	render_target_start_id: u64,
	shader:                 RenderShader,
}

CompositePass :: struct {
	root_sig:               rawptr,
	shader:                 RenderShader,
	vertex_buffer_id:       u64,
	uv_buffer_id:           u64,
	render_target_start_id: u64,
}

RenderPass :: struct($type: typeid,$list_type : typeid) {list: ^RenderCommandList(list_type), data: type}

RenderPassProcs :: struct($type: typeid) {
	setup_pass:   proc(pass: RenderPass(type)),
	execute_pass: proc(pass: RenderPass(type)),
}

//Commands
D12CommandBasicDraw :: struct {
	vertex_offset: u32,
	count:         u32,
	topology:      platform.D3D12_PRIMITIVE_TOPOLOGY,
	heap_count:    u32,
	//ID3D12DescriptorHeap* heaps;
	buffer_view:   platform.D3D12_VERTEX_BUFFER_VIEW, // TODO(Ray Garner): add a way to bind multiples
	                                                  // TODO(Ray Garner): add a way to bind multiples
}

D12CommandIndexedDraw :: struct {
	index_count:       u32,
	index_offset:      u32,
	topology:          platform.D3D12_PRIMITIVE_TOPOLOGY,
	heap_count:        u32,
	//    D3D12_VERTEX_BUFFER_VIEW uv_view,
	//    D3D12_VERTEX_BUFFER_VIEW buffer_view,// TODO(Ray Garner): add a way to bind multiples

	index_buffer_view: platform.D3D12_INDEX_BUFFER_VIEW,
	// TODO(Ray Garner): add a way to bind multiples
}

D12CommandSetVertexBuffer :: struct {
	slot:        u32,
	buffer_view: platform.D3D12_VERTEX_BUFFER_VIEW,
}

D12CommandViewport :: struct {
	viewport: enginemath.f4,
}

D12CommandRootSignature :: struct {
	root_sig: rawptr, /*ID3D12RootSignature**/
}

D12RenderCommand :: union {
	D12CommandBasicDraw,
	D12CommandIndexedDraw,
	D12CommandSetVertexBuffer,
	D12CommandViewport,
	D12CommandRootSignature,
	D12CommandPipelineState,
	D12CommandScissorRect,
	D12CommandGraphicsRootDescTable,
	D12CommandGraphicsRoot32BitConstant,
	D12CommandStartCommandList,
	D12CommandEndCommmandList,
	D12RenderTargets,
	D12CommandClear,
	D12CommandDepthStencilClear,
    D12CommandSetStencilReference,
    D12CommandCallback,
}

D12CommandPipelineState :: struct {
	pipeline_state: rawptr, /*ID3D12PipelineState* */
}

D12CommandScissorRect :: struct {
	rect: platform.D3D12_RECT,
}

D12CommandGraphicsRootDescTable :: struct {
	index:      u64,
	heap:       rawptr, /*(ID3D12DescriptorHeap* )*/
	gpu_handle: platform.D3D12_GPU_DESCRIPTOR_HANDLE,
}

D12CommandGraphicsRoot32BitConstant :: struct {
	index:      u32,
	num_values: u32,
	gpuptr:     rawptr,
	offset:     u32,
}

D12CommandStartCommandList :: struct {
	render_target_count:   int,
	render_targets:        ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,
	disable_render_target: bool,
}

D12CommandEndCommmandList :: struct {
	dummy: bool,
}

D12CommandClear :: struct {
	color:         enginemath.f4,
	resource_id:   u64,
	render_target: platform.D3D12_CPU_DESCRIPTOR_HANDLE,
}

D12CommandCallback :: struct{
	data : rawptr,
	callback : proc(data : rawptr,data2 : rawptr),
}


D12CommandDepthStencilClear :: struct {
	clear_depth:   bool,
	depth:         f32,
	clear_stencil: bool,
	stencil:       u8,
	resource:      rawptr,
	render_target: ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,
}

D12CommandSetStencilReference :: struct{
    ref : u32,
}

D12RenderTargets :: struct {
	is_desc_range:        bool,
	count:                u32,
	descriptors:          ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,
	depth_stencil_handle: ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,
}

renderer_init :: proc(capacity_count: u32,$list_type : typeid,$buffer_type : typeid) -> RenderCommandList(list_type) {
	result: RenderCommandList(list_type);
    result.list.command_buffer = con.buf_init(cast(u64)capacity_count, buffer_type);
	return result;
}

renderer_set_write_list :: proc(current_list: ^RenderCommandList(GeometryRenderCommandList)) {
	//render_commands_ptr = current_list;
}

process_children_recrusively :: proc(render: ^RenderCommandList(GeometryRenderCommandList), light_render: ^RenderCommandList(LightRenderCommandList), so: ^SceneObject, c_mat: u64, p_mat: u64, ctx: ^AssetContext) {
	using con;
    using enginemath;
	for i := 0; i < cast(int)buf_len(so.children.buffer); i += 1 {
		child_so_id := buf_get(&so.children.buffer, cast(u64)i);
		child_so    := buf_chk_out(&ctx.scene_objects, child_so_id);
		transform_update(&child_so.transform);

		if child_so.import_type != SceneObjectType.empty {
			final_mat := buf_chk_out(&ctx.asset_tables.matrix_buffer, child_so.m_id);
			final_mat^ = child_so.transform.m;
			buf_chk_in(&ctx.asset_tables.matrix_buffer);

			for m := child_so.primitives_range.x; m <= child_so.primitives_range.y; m += 1 {
				mesh_id := cast(u64)m;
				m_      := buf_chk_out(&ctx.asset_tables.meshes, mesh_id);
				if m_ != nil {
					mesh := m_^;
					//get mesh issue render command
					com := RenderCommand{};
					geo := RenderGeometry{};
					//TODO(Ray):No point in this if else statement change it.
					if mesh.index32_count > 0 {
						com.is_indexed = true;
						geo.buffer_id_range = mesh.mesh_resource.buffer_range;
						geo.index_id = cast(u64)mesh.mesh_resource.index_id;
						geo.index_count = mesh.index32_count;
					} else if mesh.index16_count > 0 {
						com.is_indexed = true;
						geo.buffer_id_range = mesh.mesh_resource.buffer_range;
						geo.index_id = cast(u64)mesh.mesh_resource.index_id;
						geo.index_count = mesh.index16_count;
					} else {
						com.is_indexed = false;
						geo.buffer_id_range = mesh.mesh_resource.buffer_range;
						geo.index_id = cast(u64)mesh.mesh_resource.index_id;
						geo.count = mesh.vertex_count;
					}

					geo.offset = 0;
					geo.base_color = mesh.base_color;
					com.geometry = geo;

					com.material_id = cast(u64)mesh.material_id;
					com.material_name = mesh.material_name;
					com.texture_id = mesh.metallic_roughness_texture_id;
					com.model_matrix_id = child_so.m_id;
					com.camera_matrix_id = c_mat;
					com.perspective_matrix_id = p_mat;

					if child_so.type == SceneObjectType.mesh {
						buf_push(&render.list.command_buffer, com);
					} else if child_so.type == SceneObjectType.light {
                        light_command : LightRenderCommand;
                        light_command.render_command = com;
                        light_command.light.intensity = 1;
                        light_command.light.size = 1;
                        light_command.light.p = f3{0,0,0};

						buf_push(&light_render.list.command_buffer, light_command);
					}

					buf_chk_in(&ctx.asset_tables.meshes);
				}
			}
		}

		process_children_recrusively(render, light_render, child_so, c_mat, p_mat, ctx);
		buf_chk_in(&ctx.scene_objects);
	}
}

issue_render_commands :: proc(render: ^RenderCommandList(GeometryRenderCommandList), light_render: ^RenderCommandList(LightRenderCommandList), s: ^Scene, ctx: ^AssetContext, c_mat: u64, p_mat: u64) {
	using con;
	//Start at root node
	for i := 0; i < cast(int)buf_len(s.buffer.buffer); i += 1 {
		so_id := buf_get(&s.buffer.buffer, cast(u64)i);
		so    := buf_chk_out(&ctx.scene_objects, so_id);

		if buf_len(so.children.buffer) > 0 {
			process_children_recrusively(render, light_render, so, c_mat, p_mat, ctx);
		}
		buf_chk_in(&ctx.scene_objects);
	}
}

/*
//NOTE(Ray):for deffered shading 
issue_light_render_commands :: proc(render: ^RenderCommandList, s: ^Scene, ctx: ^AssetContext, c_mat: u64, p_mat: u64) {
	using con;
	//Start at root node
	for i := 0; i < cast(int)buf_len(s.lights); i += 1 {
		light := buf_get(&s.lights, cast(u64)i);
		//TODO!!! we have to create the sphere mesh to be used here!!
		light_mesh: Mesh;
		//get mesh issue render command
		com := RenderCommand{};
		geo := RenderGeometry{};
		com.is_indexed = true;
		geo.buffer_id_range = light_mesh.mesh_resource.buffer_range;
		geo.index_id = cast(u64)light_mesh.mesh_resource.index_id;
		geo.index_count = light_mesh.index32_count;

		geo.offset = 0;
		geo.base_color = light_mesh.base_color;
		com.geometry = geo;

		com.material_id = cast(u64)light_mesh.material_id;
		com.material_name = light_mesh.material_name;
		com.texture_id = light_mesh.metallic_roughness_texture_id;
		//        com.model_matrix_id = child_so.m_id;
		//        com.camera_matrix_id = c_mat;
		//        com.perspective_matrix_id = p_mat;
		buf_push(&render.command_buffer, com);
	}
}
*/
