extends Node3D

const PROBE_SPEED := 3.0
const PROBE_LIMIT := 6.0
const FADE_SHADER := preload("res://fade_probe.gdshader")
const PALETTE: Array[Color] = [
	Color("#f2a7a0"),
	Color("#f2c078"),
	Color("#f5df8c"),
	Color("#b6d59c"),
	Color("#8fc7bd"),
	Color("#8fb8d8"),
	Color("#a6a0d4"),
	Color("#c7a5cf"),
]

var duck: MeshInstance3D
var camera: Camera3D
var fade_probe: MeshInstance3D
var fade_time := 0.0


func _ready() -> void:
	_add_environment()
	_add_ground()
	_add_test_shapes()
	_add_duck_placeholder()
	_add_roof()
	_add_lighting()
	_add_camera()
	_add_fade_probes()


func _process(delta: float) -> void:
	fade_time += delta
	fade_probe.set_instance_shader_parameter("fade", (1.0 - cos(fade_time)) / 2.0)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("probe_left", "probe_right", "probe_forward", "probe_back")
	var right := camera.global_basis.x
	var backward := camera.global_basis.z
	right.y = 0.0
	backward.y = 0.0
	var movement := right.normalized() * input.x + backward.normalized() * input.y
	duck.position += movement * PROBE_SPEED * delta
	duck.position.x = clampf(duck.position.x, -PROBE_LIMIT, PROBE_LIMIT)
	duck.position.z = clampf(duck.position.z, -PROBE_LIMIT, PROBE_LIMIT)


func _add_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.glow_enabled = true
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.008

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func _add_ground() -> void:
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(30.0, 30.0)
	ground.mesh = ground_mesh
	ground.position.y = -0.05

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d9e3cb")
	material.roughness = 1.0
	ground.material_override = material
	add_child(ground)


func _add_test_shapes() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56

	var materials: Array[StandardMaterial3D] = []
	for color in PALETTE:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.82
		materials.append(material)

	for index in range(100):
		var shape := MeshInstance3D.new()
		shape.mesh = sphere
		shape.material_override = materials[index % materials.size()]
		shape.position = Vector3(float(index % 10) - 4.5, 0.3, -4.0 - float(index / 10) * 0.9)
		add_child(shape)


func _add_duck_placeholder() -> void:
	duck = MeshInstance3D.new()
	duck.name = "DuckPlaceholder"
	var duck_mesh := CapsuleMesh.new()
	duck_mesh.radius = 0.42
	duck_mesh.height = 1.3
	duck.mesh = duck_mesh
	duck.position = Vector3(0.0, 0.65, 4.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#f4d45c")
	material.roughness = 0.7
	material.stencil_color = Color(0.9, 0.25, 0.8, 0.85)
	material.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
	duck.material_override = material
	add_child(duck)


func _add_roof() -> void:
	var post_material := StandardMaterial3D.new()
	post_material.albedo_color = Color("#c58e73")
	post_material.roughness = 0.9

	for x in [-2.5, 2.5]:
		for z in [-2.5, 2.5]:
			var post := MeshInstance3D.new()
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.16, 2.8, 0.16)
			post.mesh = post_mesh
			post.position = Vector3(x, 1.4, z)
			post.material_override = post_material
			add_child(post)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(5.3, 0.24, 5.3)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 2.85, 0.0)
	roof.material_override = post_material
	add_child(roof)


func _add_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)


func _add_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(11.0, 10.0, 15.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.7, -1.0))


func _add_fade_probes() -> void:
	var material := ShaderMaterial.new()
	material.shader = FADE_SHADER
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.8, 1.2, 0.8)

	for index in range(2):
		var box := MeshInstance3D.new()
		box.name = "FadeControl" if index == 0 else "FadeProbe"
		box.mesh = box_mesh
		box.material_override = material
		box.position = Vector3(-4.5 + float(index) * 1.6, 0.6, 4.0 - float(index) * 1.1)
		box.set_instance_shader_parameter("fade", 0.0)
		add_child(box)
		if index == 1:
			fade_probe = box
