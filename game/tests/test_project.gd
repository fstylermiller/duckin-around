extends GutTest

const MAIN_SCENE := preload("res://main.tscn")


func test_main_scene_can_be_instantiated() -> void:
	var scene := MAIN_SCENE.instantiate()
	assert_not_null(scene)
	scene.free()


func test_left_stick_axes_are_mapped_to_probe_actions() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = 0
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = -1.0
	assert_true(motion.is_action_pressed("probe_left"))
	assert_false(motion.is_action_pressed("probe_right"))
	motion.axis_value = 1.0
	assert_true(motion.is_action_pressed("probe_right"))
	motion.axis = JOY_AXIS_LEFT_Y
	motion.axis_value = -1.0
	assert_true(motion.is_action_pressed("probe_forward"))
	motion.axis_value = 1.0
	assert_true(motion.is_action_pressed("probe_back"))


func test_probe_moves_right_and_stops_when_released() -> void:
	var scene = MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	var duck := scene.get_node("DuckPlaceholder") as MeshInstance3D
	var start := duck.position
	Input.action_press("probe_right")
	scene._physics_process(1.0)
	Input.action_release("probe_right")
	var moved := duck.position
	assert_gt(moved.distance_to(start), 0.0)
	var displacement: Vector3 = moved - start
	assert_gt(displacement.dot(scene.camera.global_basis.x), 0.0)
	scene._physics_process(1.0)
	assert_eq(duck.position, moved)


func test_fade_probe_changes_only_one_shared_material_instance() -> void:
	var scene = MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	var control := scene.get_node("FadeControl") as MeshInstance3D
	var probe := scene.get_node("FadeProbe") as MeshInstance3D
	assert_same(control.material_override, probe.material_override)
	scene._process(PI)
	assert_almost_eq(float(probe.get_instance_shader_parameter("fade")), 1.0, 0.001)
	assert_almost_eq(float(control.get_instance_shader_parameter("fade")), 0.0, 0.001)


func test_duck_uses_stencil_xray_for_occluded_parts() -> void:
	var scene = MAIN_SCENE.instantiate()
	add_child_autofree(scene)
	var duck := scene.get_node("DuckPlaceholder") as MeshInstance3D
	var material := duck.material_override as StandardMaterial3D
	assert_eq(material.stencil_mode, BaseMaterial3D.STENCIL_MODE_XRAY)
