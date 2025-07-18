extends Node3D
## Handles player head-bobbing

signal bob_head
signal recenter

const MIN_RETURN_RATIO = 0.3
const TRANS_MODE = Tween.TRANS_LINEAR

## The angle that the camera will rotate along the z-axis when head-bobbing
@export var bob_angle := 0.0
## The offset the camera will move to along the x-axis when head-bobbing. Head will bob from 0 to -x to 0 to x
@export var bob_offset_x := 0.03
## The offset the camera will move to along the y-axis when head-bobbing. Head will bob from 0 to y to 0 to y
@export var bob_offset_y := -0.05
## The time it will take for the camera to rotate from 0 degrees to `bob_angle` degrees
@export var bob_duration := 0.3

var position_y = position.y
# var rotation_tween: Tween
var position_tween: Tween
var return_tween: Tween

var bobbing := true
var current_target := Vector2.ZERO


func _ready() -> void:
    recenter.connect(recenter_head)
    await head_bob()


func recenter_head() -> void:
    if position_tween == null or not position_tween.is_running():
        return

    bobbing = false

    # rotation_tween.stop()
    # rotation_tween.finished.emit()
    position_tween.stop()
    position_tween.finished.emit()

    var ratio_x = abs(current_target.x - position.x) / bob_offset_x
    ratio_x = ratio_x if ratio_x > MIN_RETURN_RATIO else MIN_RETURN_RATIO
    var ratio_y = abs(current_target.y - (position.y - position_y)) / (bob_offset_y)
    ratio_y = ratio_y if ratio_y > MIN_RETURN_RATIO else MIN_RETURN_RATIO
    return_tween = create_tween()
    return_tween.set_parallel()
    return_tween.tween_property(self, "position:x", 0, bob_duration * ratio_x).set_trans(TRANS_MODE)
    return_tween.tween_property(self, "position:y", position_y, bob_duration * ratio_y).set_trans(
        TRANS_MODE
    )
    return_tween.finished.connect(func(): bobbing = true)


func head_bob() -> void:
    while true:
        await bob_head
        if not bobbing:
            continue

        _create_tweens(bob_angle, -1 * bob_offset_x, bob_offset_y)
        await position_tween.finished
        if not bobbing:
            continue

        _create_tweens(0, 0, 0)
        await position_tween.finished
        await bob_head
        if not bobbing:
            continue

        _create_tweens(-1 * bob_angle, bob_offset_x, bob_offset_y)
        await position_tween.finished
        if not bobbing:
            continue

        _create_tweens(0, 0, 0)
        await position_tween.finished
        if not bobbing:
            continue


## Create two tweens to tween this object by `angle` and `offset` over `self.bob_duration`
func _create_tweens(_angle: float, offset_x: float, offset_y: float) -> void:
    # rotation_tween = create_tween()
    # rotation_tween.tween_property(self, "rotation:z", deg_to_rad(angle) * 0, bob_duration).set_trans(TRANS_MODE)
    position_tween = create_tween()
    position_tween.set_parallel()
    (
        position_tween
        . tween_property(self, "position:x", offset_x, bob_duration)
        . set_trans(Tween.TRANS_LINEAR)
        . set_trans(TRANS_MODE)
    )
    (
        position_tween
        . tween_property(self, "position:y", offset_y + position_y, bob_duration)
        . set_trans(Tween.TRANS_LINEAR)
    )
    current_target = Vector2(offset_x, offset_y)
