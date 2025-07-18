extends CharacterBody3D
## Handles player movement, jumping, and gravity

@export_group("Camera settings")
@export_range(1, 100, 1) var mouse_sensitivity := 50
@export var max_x_rotation := 89.0
@export var min_x_rotation := -89.0

@export_group("Player movement settings")
@export var move_speed := 3.0
## The upward velocity of a jump
@export var jump_velocity := 4.5
## The percentage of the players walk velocity that caries into a jump
@export var xz_jump_velocity := 0.75
## The percentage of the players walk velocity to apply when airborne
@export var xz_air_velocity := 0.01

@export_group("Dev controls")
@export var dev_controls_enabled := true
@export var min_speed := 0.1
@export var max_speed := 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed_mod := 1.0  # Modifier to player speed that can be adjusted with mouse wheel
var flying := false
var collider: CollisionShape3D
var camera: Camera3D
var mouse_inverted := false


func _ready() -> void:
    Globals.change_mouse_sensitivity.connect(_change_sensitivity)
    Globals.change_mouse_invertion.connect(_set_mouse_invertion)
    Globals.change_fov.connect(_change_fov)

    camera = find_children("", "Camera3D")[0]
    collider = find_children("", "CollisionShape3D")[0]
    # Input.set_use_accumulated_input(false)


func _input(event) -> void:
    if event is InputEventMouseMotion:
        _rotate_cam(event)

    if event is InputEventKey:
        if event.is_action_pressed("player_flight_toggle") and dev_controls_enabled:
            flying = not flying
        elif event.is_action_pressed("player_toggle_collision") and dev_controls_enabled:
            collider.disabled = not collider.disabled

    if event is InputEventMouseButton:
        var mw_input_scale: float = 0.1
        if event.is_action_pressed("mw_down") and dev_controls_enabled:
            speed_mod -= mw_input_scale
            speed_mod = speed_mod if speed_mod > min_speed else min_speed
        elif event.is_action_pressed("mw_up") and dev_controls_enabled:
            speed_mod += mw_input_scale
            speed_mod = speed_mod if speed_mod < max_speed else max_speed


func _physics_process(delta: float) -> void:
    # Move player
    if not is_on_floor() and not flying:
        velocity.y -= gravity * delta

    _walk_and_jump()
    move_and_slide()
    orthonormalize()


## Handle player input for walking and jumping using the player_ input actions
func _walk_and_jump():
    var input_dir = Input.get_vector("player_left", "player_right", "player_forward", "player_back")
    var height_change = Input.get_axis("player_down", "player_up")

    var direction
    if flying:
        direction = ((global_basis * Vector3(input_dir.x, height_change, input_dir.y)).normalized())
    else:
        direction = (global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

    if direction:
        velocity.x = direction.x * move_speed * speed_mod
        velocity.z = direction.z * move_speed * speed_mod
        if flying:
            velocity.y = direction.y * move_speed * speed_mod
        else:
            camera.bob_head.emit()
    else:
        camera.recenter.emit()
        velocity.x = move_toward(velocity.x, 0, move_speed * speed_mod)
        velocity.z = move_toward(velocity.z, 0, move_speed * speed_mod)
        if flying:
            velocity.y = move_toward(velocity.y, 0, move_speed * speed_mod)

    if Input.is_action_just_pressed("player_up") and is_on_floor() and not flying:
        velocity.y = jump_velocity


## Handle mouse input for camera rotation [br]
## `event`: mouse movement to be used to rotate the camera.
func _rotate_cam(event: InputEventMouseMotion) -> void:
    var viewport_transform: Transform2D = get_tree().root.get_final_transform()
    var motion: Vector2 = event.xformed_by(viewport_transform).relative
    var degrees_per_unit: float = 0.001

    motion *= mouse_sensitivity
    motion *= degrees_per_unit

    rotate_object_local(Vector3.DOWN, deg_to_rad(motion.x))
    camera.rotate_object_local(
        Vector3.LEFT, deg_to_rad(-1 * motion.y if mouse_inverted else motion.y)
    )
    camera.rotation.x = clamp(
        camera.rotation.x, deg_to_rad(min_x_rotation), deg_to_rad(max_x_rotation)
    )
    camera.orthonormalize()


func _change_sensitivity(sensitivity: int) -> void:
    mouse_sensitivity = sensitivity


func _set_mouse_invertion(inverted: bool) -> void:
    mouse_inverted = inverted


func _change_fov(fov: int) -> void:
    camera.fov = fov
