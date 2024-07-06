extends Node

class_name ClientInputHandler

const FULL_ROTATION_DEGREES = 360
const MOUSE_SENSITIVITY = 0.05

var __yaw_deg: float = 0
var __pitch_deg: float = 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED):
		__yaw_deg = normalize_angle_to_positive_degrees(__yaw_deg - (event.relative.x) * MOUSE_SENSITIVITY)
		__pitch_deg = clamp(__pitch_deg - (event.relative.y * MOUSE_SENSITIVITY), -90.0, 90.0)
	elif event.is_action_pressed("toggle_mouse_mode"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func latest_input() -> InputState:
	return InputState.new(
		__yaw_deg,
		__pitch_deg,
		Input.is_action_pressed("jump"),
		Input.is_action_pressed("slow"),
		Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	)

func reset_view_angle() -> void:
	__yaw_deg = 0
	__pitch_deg = 0

func normalize_angle_to_positive_degrees(angle: float):
	angle = fmod(angle, FULL_ROTATION_DEGREES)
	return angle + FULL_ROTATION_DEGREES if angle < 0 else angle
