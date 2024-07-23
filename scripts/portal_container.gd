@tool
class_name PortalContainer extends Node3D
## TODO

## Resolution scale of portals. `1.0 = full resolution`
@export_range(0.1, 1, 0.1) var resolution_scale: float = 1
## `CharacterBody3D` with a `Camera3D` child
@export var player: CharacterBody3D
## Width, height, and depth of both portals
@export var portal_size: Vector3 = Vector3(1, 2, 0.2)
## Render layer for each portal (by child order). These layers will be disabled for each portal's camera respectively
@export var render_layers: Vector2i = Vector2i(9, 10)
## Layer that portal collision will take place on
@export var trigger_layer_mask: int = 2
## Cull mask for the camera rendering the first portal's view
@export_flags_3d_render var cam_0_cull_mask
## Cull mask for the camera rendering the second portal's view
@export_flags_3d_render var cam_1_cull_mask

var portal_0: Portal
var portal_1: Portal
var viewport_0: SubViewport
var viewport_1: SubViewport
var cam_0: Camera3D
var cam_1: Camera3D
var constructed: bool = false
var deployed: bool = false

static var cam_env: Environment
static var target_cam: Camera3D

## Size of portal stash
static var queue_size: int = 3
## Queue of stashed portals. Portals are destroyed when removed from the queue
static var portal_delete_queue: Array[PortalContainer] = []

var box_mesh: BoxMesh = BoxMesh.new() # Needed for viewing the portal meshes in the editor
## Editor-only var
var child_count = get_children().size()

# Constants
var WORLD_ENV_PATH = '/root/Main/WorldEnvironment'

func _ready():
	box_mesh.size = portal_size
	var portals = find_children('', 'Portal')

	if Engine.is_editor_hint():
		if portals.size() == 2:
			portal_0 = portals[0]
			portal_1 = portals[1]
			portal_0.update_mesh(box_mesh, render_layers.x)
			portal_1.update_mesh(box_mesh, render_layers.y)
		return

	# Create camera environment, disable troublesome effects
	var world_env = get_node(WORLD_ENV_PATH)
	if world_env != null and cam_env == null:
		cam_env = world_env.environment.duplicate()
		cam_env.glow_enabled = false

	# Set target cam from player
	if target_cam == null:
		target_cam = player.find_children('', 'Camera3D')[0]

	# Init portal 0
	portal_0 = portals[0]
	portal_0.update_mesh(box_mesh, render_layers.x)
	var area_3d_0 = _create_collider(portal_0, trigger_layer_mask)
	add_child(area_3d_0)
	var vis_notif_0 = _create_visibility_notifier(portal_0, render_layers.x)
	# Connect signals
	area_3d_0.connect('body_entered', func(_body): portal_0.player_in_portal = true)
	area_3d_0.connect('body_exited', func(_body): portal_0.player_in_portal = false)
	vis_notif_0.connect('screen_entered', func(): portal_0.on_screen = true)
	vis_notif_0.connect('screen_exited', func(): portal_0.on_screen = false)

	# Init portal 1
	portal_1 = portals[1]
	portal_1.update_mesh(box_mesh, render_layers.y)
	var area_3d_1 = _create_collider(portal_1, trigger_layer_mask)
	add_child(area_3d_1)
	var vis_notif_1 = _create_visibility_notifier(portal_1, render_layers.y)
	# Connect signals
	area_3d_1.connect('body_entered', func(_body): portal_1.player_in_portal = true)
	area_3d_1.connect('body_exited', func(_body): portal_1.player_in_portal = false)
	vis_notif_1.connect('screen_entered', func(): portal_1.on_screen = true)
	vis_notif_1.connect('screen_exited', func(): portal_1.on_screen = false)

func _process(_delta):
	if Engine.is_editor_hint():
		update_configuration_warnings()
		box_mesh.size = portal_size

		# Verify that portals are still children when children change
		var cur_child_count = get_children().size()
		if child_count != cur_child_count:
			child_count = cur_child_count
			portal_0 = null
			portal_1 = null

			var portals = find_children('', 'Portal')
			if portals.size() == 2:
				portal_0 = portals[0]
				portal_1 = portals[1]
				portal_0.update_mesh(box_mesh, render_layers.x)
				portal_1.update_mesh(box_mesh, render_layers.y)
			return

		# Ensure portal meshes are assigned in the editor
		if portal_0 != null and portal_0.mesh == null:
				portal_0.update_mesh(box_mesh, render_layers.x)
		if portal_1 != null and portal_1.mesh == null:
				portal_1.update_mesh(box_mesh, render_layers.y)

		return

	var portals_on_screen = portal_0.on_screen or portal_1.on_screen
	var player_in_portals = portal_0.player_in_portal or portal_1.player_in_portal

	# Construct/deploy if the player can see either portal or if the player is in either portal
	if (portals_on_screen or player_in_portals) and not deployed:
		if not constructed:
			construct()
		elif not deployed:
			deploy()
	# Deactivate if neither portal is on the screen and the player is not in either portal
	elif not (portals_on_screen or player_in_portals) and deployed:
		deactivate()
		return


	var oblique_cutoff = portal_size.z
	# Teleport player
	if _check_player_can_teleport(portal_0, portal_size.z / 2):
		portal_0.player_in_portal = false
		portal_1.on_screen = true
		player.global_transform = _get_relative_transform(
			player.global_transform,
			portal_0.global_transform,
			portal_1.global_transform,
			portal_size.z / 2,
			true,
		)
	elif _check_player_can_teleport(portal_1, portal_size.z / 2):
		portal_1.player_in_portal = false
		portal_0.on_screen = true
		player.global_transform = _get_relative_transform(
			player.global_transform,
			portal_1.global_transform,
			portal_0.global_transform,
			portal_size.z / 2,
			true,
		)

	# Only move cameras when needed
	if portal_0.on_screen:
		cam_1.global_transform = _get_relative_transform(
			target_cam.global_transform,
			portal_0.global_transform,
			portal_1.global_transform,
			portal_size.z
		)
		# Disable oblique frustum when the player gets close to prevent flickering issue
		cam_1.use_oblique_frustum = abs(portal_0.to_local(target_cam.global_position).z) > oblique_cutoff

	if portal_1.on_screen:
		cam_0.global_transform = _get_relative_transform(
			target_cam.global_transform,
			portal_1.global_transform,
			portal_0.global_transform,
			portal_size.z
		)
		# Disable oblique frustum when the player gets close to prevent flickering issue
		cam_0.use_oblique_frustum = abs(portal_1.to_local(target_cam.global_position).z) > oblique_cutoff

## Calculate gobal transform of `current` relative to `reference`, apply the same offest to `target`.
## Optionally, apply a z offest/overwrite to the output [br]
## `current`: The global transform of interest [br]
## `reference`: The transform that `current` is relative to [br]
## `target`: The transform that the returned transform's perspective is relative to [br]
## `z_offset`: Optional z offset to apply before transform is rotated into `target` perspective [br]
## `z_overwrite`: `if true`, `z_offset` will overwrite the transforms z value [br]
## Returns `global_transform`: The global transform `current` but now relative to `target`
func _get_relative_transform(
	current: Transform3D,
	reference: Transform3D,
	target: Transform3D,
	z_offset: float = 0,
	z_overwrite: bool = false,
) -> Transform3D:
	var transform_offset = reference.affine_inverse() * current
	var offset_sign = -1 * sign(transform_offset.origin.z)
	if z_overwrite:
		transform_offset.origin.z = offset_sign * z_offset
	else:
		transform_offset.origin.z += offset_sign * z_offset

	return target * transform_offset

## Check if `player`'s `z_offset` from `portal` is close enough to teleport [br]
## Returns `player_can_teleport: bool`
func _check_player_can_teleport(portal: Portal, z_offset) -> bool:
	if not portal.player_in_portal:
		return false

	var player_in_portal_frame = (
		portal.basis.inverse() * (player.global_position - portal.global_position)
	)

	return abs(player_in_portal_frame.z) <= z_offset

## Create and initialize `SubViewport` and `Camera3D` objects with desired params [br]
## Returns `viewport: Subviewprt` [br]
## `cull_mask`: The created camera's cull mask [br]
## `portal_render_layer`: The render layer the portal will display on,
## this layer is disabled for the created camera [br]
## `cam_oblique_normal`: The normal direction of the portal this camera is for [br]
## `cam_oblique_pos`: The position of the portal this camera is for [br]
## `cam_far_plane`: Optional, the far plane of the created camera [br]
## Returns `viewport`: a `Subviewport` with a `Camera3D` child
func _create_viewport_and_cam(
	cull_mask: int,
	portal_render_layer: int,
	cam_oblique_normal: Vector3,
	cam_oblique_pos: Vector3,
	cam_far_plane: float = 500,
) -> SubViewport:
	var texture_size = Vector2i(DisplayServer.screen_get_size() * resolution_scale)

	# Create viewport
	var viewport = SubViewport.new()
	viewport.size = texture_size
	# NOTE: this might not be optimal
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	viewport.handle_input_locally = true

	# Create camera
	var cam = Camera3D.new()
	cam.fov = target_cam.fov
	cam.cull_mask = cull_mask
	cam.set_cull_mask_value(portal_render_layer, false)
	cam.environment = cam_env
	cam.use_oblique_frustum = true
	cam.oblique_normal = cam_oblique_normal
	cam.oblique_position = cam_oblique_pos
	cam.far = cam_far_plane

	# Parent camera
	viewport.add_child(cam)

	return viewport

## Create and initialize `VisibleOnScreenNotifier3D` object with desired params [br]
## `portal`: the portal that this notifier is for [br]
## `mask`: the layer that the visibility notifier will be on [br]
## Returns `vis_notif: VisibleOnScreenNotifier3D`
func _create_visibility_notifier(portal: Portal, mask: int)  -> VisibleOnScreenNotifier3D:
	# Create and set notifier
	var vis_notif = VisibleOnScreenNotifier3D.new()
	for i in range(1, 21): vis_notif.set_layer_mask_value(i, false)
	vis_notif.set_layer_mask_value(mask, true)
	add_child(vis_notif)
	vis_notif.transform = portal.transform
	vis_notif.aabb = AABB(
		portal.mesh.size / -2,
		portal.mesh.size,
	)

	return vis_notif

## Create and initialize `Area3D` and an associated box collider [br]
## `portal`: the portal to create `Area3D` for [br]
## `mask`: the layer the `Area3D` checks for collisions on [br]
## Returns `area_3d: Area3D`
func _create_collider(portal: Portal, mask: int) -> Area3D:
	# Create area
	var area_3d = Area3D.new()
	for i in range(1, 21): area_3d.set_collision_mask_value(i, false)
	area_3d.set_collision_mask_value(mask, true)

	# Create collider
	var collider = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = portal.mesh.size

	# Parent node
	area_3d.add_child(collider)
	area_3d.transform = portal.transform

	return area_3d

## Initializes viewports and cameras, sets viewport and camera variables,
## sets portal materials to viewport textures, sets `constructed = true` and `deployed = true`
func construct() -> void:
	print('constructed')
	viewport_0 = _create_viewport_and_cam(
		cam_0_cull_mask,
		render_layers.x,
		portal_0.global_basis.z,
		portal_0.global_position,
	)
	add_child(viewport_0)
	cam_0 = viewport_0.get_child(0)

	viewport_1 = _create_viewport_and_cam(
		cam_1_cull_mask,
		render_layers.y,
		portal_1.global_basis.z,
		portal_1.global_position,
	)
	add_child(viewport_1)
	cam_1 = viewport_1.get_child(0)

	# Set portal materials
	portal_1.set_material(viewport_0.get_texture())
	portal_0.set_material(viewport_1.get_texture())

	constructed = true
	deployed = true

## Enables viewports and cameras, sets portal material to viewport textures,
## sets `deployed = true`
func deploy() -> void:
	print('redeployed')
	# Enable viewports and cameras
	viewport_0.set_process(true)
	viewport_1.set_process(true)
	cam_0.set_process(true)
	cam_1.set_process(true)

	# Create material
	portal_1.set_material(viewport_0.get_texture())
	portal_0.set_material(viewport_1.get_texture())

	# remove from stash
	var stash_index = portal_delete_queue.bsearch(self)
	portal_delete_queue.remove_at(stash_index)
	print(portal_delete_queue)

	deployed = true

## Disables viewports and cameras, deletes portal materials, sets `deployed = false`,
## removes first element of `portal_delete_queue` and calls its `deconstruct()` function
func deactivate() -> void:
	print('deactivated')
	# Update queue
	if portal_delete_queue.size() >= queue_size:
		var portal_to_del = portal_delete_queue.pop_front()
		portal_to_del.deconstruct()

	portal_delete_queue.push_back(self)
	print(portal_delete_queue)

	# Deactivate
	portal_0.remove_material()
	portal_1.remove_material()
	if viewport_0 != null:
		viewport_0.set_process(false)
	if viewport_1 != null:
		viewport_1.set_process(false)
	if cam_0 != null:
		cam_0.set_process(false)
	if cam_1 != null:
		cam_1.set_process(false)

	deployed = false

## Frees `viewport_0` and `viewport_1` (and their nested cameras). sets `constructed = false`
func deconstruct() -> void:
	print('destroyed')
	viewport_0.queue_free()
	viewport_0 = null
	cam_0 = null
	viewport_1.queue_free()
	viewport_1 = null
	cam_1 = null

	constructed = false

func _get_configuration_warnings():
	var portal_count = 0
	for child in get_children():
		if child is Portal:
			portal_count += 1

	var warnings = []
	if portal_count != 2:
		warnings.append(
			'This node does not have the correct number of Portals.
			Portal count should be 2'
		)

	return warnings
