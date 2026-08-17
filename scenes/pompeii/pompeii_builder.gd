class_name PompeiiBuilder
extends RefCounted

const MeshUtil := preload("res://scripts/mesh_util.gd")

const CIV := preload("res://scenes/npcs/civilian.tscn")
const GUARD := preload("res://scenes/npcs/guard.tscn")
const BARROW := preload("res://scenes/props/wheelbarrow.tscn")
const COIN := preload("res://scenes/props/coin.tscn")
const ZONE := preload("res://scenes/props/safe_zone.tscn")
const HATCH := preload("res://scenes/props/trap_door.tscn")
const LEMON := preload("res://scenes/npcs/evil_lemon.tscn")
const CivilianType := preload("res://scenes/npcs/civilian.gd")


static func build(root: Node3D) -> void:
	_environment(root)
	var map := Node3D.new()
	map.name = "MapRoot"
	root.add_child(map)
	_ground(map)
	_forum(map)
	_houses(map)
	_temple(map)
	_volcano(root, map)
	_prison(root, map)
	_zones(root)
	_people(root)
	_barrows(root)
	_coins(root)


static func _environment(root: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c9844a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9a06a")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("d4894c")
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = env
	root.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 150, 0)
	sun.light_color = Color("ffc27a")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	root.add_child(sun)


static func _ground(map: Node3D) -> void:
	MeshUtil.add_static_box(map, Vector3(140, 1, 140), Color("c6864a"), Vector3(0, -0.5, 0))
	MeshUtil.add_static_box(map, Vector3(24, 0.12, 24), Color("b9a089"), Vector3(0, 0.06, 0))
	MeshUtil.add_static_box(map, Vector3(8, 0.08, 36), Color("a88868"), Vector3(0, 0.04, -18))
	MeshUtil.add_static_box(map, Vector3(40, 0.08, 8), Color("a88868"), Vector3(0, 0.04, 0))


static func _forum(map: Node3D) -> void:
	for x in [-9.0, 9.0]:
		for z in [-8.0, 0.0, 8.0]:
			MeshUtil.add_static_box(map, Vector3(1.1, 3.4, 1.1), Color("d8c4a8"), Vector3(x, 1.7, z))
			MeshUtil.add_static_box(map, Vector3(1.6, 0.35, 1.6), Color("eee0c8"), Vector3(x, 3.5, z))
	MeshUtil.add_static_box(map, Vector3(6, 0.4, 6), Color("8b2e1f"), Vector3(0, 0.25, 0))
	var plaque := Label3D.new()
	plaque.text = "FORUM"
	plaque.position = Vector3(0, 2.4, 0)
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plaque.font_size = 48
	map.add_child(plaque)


static func _houses(map: Node3D) -> void:
	var blocks := [
		[Vector3(-18, 2.1, -10), Vector3(8, 4.2, 7), Color("c45c3a")],
		[Vector3(-17, 2.0, 8), Vector3(7, 4.0, 6), Color("b55232")],
		[Vector3(18, 2.2, -8), Vector3(8, 4.4, 7), Color("a84a2c")],
		[Vector3(19, 1.8, 10), Vector3(7, 3.6, 6), Color("c4683c")],
		[Vector3(-8, 1.9, 16), Vector3(6, 3.8, 6), Color("9a4030")],
		[Vector3(8, 1.9, 16), Vector3(6, 3.8, 6), Color("b85a36")],
		[Vector3(-22, 1.6, -22), Vector3(6, 3.2, 5), Color("8e3c28")],
		[Vector3(16, 2.4, -22), Vector3(5, 2.2, 5), Color("d2b48c")],
	]
	for block in blocks:
		MeshUtil.add_static_box(map, block[1], block[2], block[0])
		MeshUtil.add_static_box(map, Vector3(block[1].x + 0.4, 0.35, block[1].z + 0.4), Color("6b2a1c"), block[0] + Vector3(0, block[1].y * 0.5 + 0.1, 0))


static func _temple(map: Node3D) -> void:
	MeshUtil.add_static_box(map, Vector3(12, 0.6, 10), Color("e6d3b0"), Vector3(0, 0.3, -28))
	MeshUtil.add_static_box(map, Vector3(8, 4.5, 0.6), Color("efe0c4"), Vector3(0, 2.6, -32))
	for x in [-4.0, -1.3, 1.3, 4.0]:
		MeshUtil.add_static_box(map, Vector3(0.8, 3.6, 0.8), Color("f0e2c6"), Vector3(x, 2.1, -24.5))
	var label := Label3D.new()
	label.text = "TEMPLE OF JUPITER\n(and also snacks)"
	label.position = Vector3(0, 5.4, -28)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	map.add_child(label)


static func _volcano(root: Node3D, map: Node3D) -> void:
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.0
	mesh.bottom_radius = 18.0
	mesh.height = 22.0
	cone.mesh = mesh
	cone.material_override = MeshUtil.make_material(Color("5a3328"))
	cone.position = Vector3(0, 10.5, 62)
	map.add_child(cone)
	MeshUtil.add_sphere(map, 3.2, Color("ff5a1a"), Vector3(0, 21.5, 62), 2.8)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 22, 62)
	glow.light_color = Color("ff6a22")
	glow.light_energy = 4.0
	glow.omni_range = 40
	map.add_child(glow)
	var label := Label3D.new()
	label.text = "VESUVIUS\n(t-minus 2 minutes)"
	label.position = Vector3(0, 24, 62)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.modulate = Color("ffb080")
	map.add_child(label)
	_volcano_cave(root, map)


static func _volcano_cave(root: Node3D, map: Node3D) -> void:
	MeshUtil.add_static_box(map, Vector3(14, 0.18, 16), Color("3a1c14"), Vector3(0, 0.09, 68))
	MeshUtil.add_static_box(map, Vector3(3.2, 4.2, 8.5), Color("4a261c"), Vector3(-5.4, 2.1, 56))
	MeshUtil.add_static_box(map, Vector3(3.2, 4.2, 8.5), Color("4a261c"), Vector3(5.4, 2.1, 56))
	MeshUtil.add_static_box(map, Vector3(14, 4.2, 1.4), Color("4a261c"), Vector3(0, 2.1, 76.2))
	MeshUtil.add_static_box(map, Vector3(1.4, 4.2, 14), Color("4a261c"), Vector3(-7.2, 2.1, 68))
	MeshUtil.add_static_box(map, Vector3(1.4, 4.2, 14), Color("4a261c"), Vector3(7.2, 2.1, 68))
	var mouth := Label3D.new()
	mouth.text = "DO NOT ENTER\n(evil lemons live here)"
	mouth.position = Vector3(0, 3.4, 50)
	mouth.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mouth.font_size = 22
	mouth.modulate = Color("ff8866")
	map.add_child(mouth)
	var lemon_i := 1
	for pos in [Vector3(0, 0, 66), Vector3(3.4, 0, 70), Vector3(-3.2, 0, 70), Vector3(1.6, 0, 73.5), Vector3(-2.2, 0, 64.5)]:
		var lemon: Node3D = LEMON.instantiate()
		lemon.name = "EvilLemon%02d" % lemon_i
		lemon.position = pos
		root.add_child(lemon)
		lemon_i += 1


static func _prison(root: Node3D, map: Node3D) -> void:
	MeshUtil.add_static_box(map, Vector3(10, 0.3, 8), Color("4a4a4a"), Vector3(-40, 3.6, 38))
	MeshUtil.add_static_box(map, Vector3(10, 3.4, 0.4), Color("3a3a3a"), Vector3(-40, 1.7, 34.2))
	MeshUtil.add_static_box(map, Vector3(0.4, 3.4, 8), Color("3a3a3a"), Vector3(-44.8, 1.7, 38))
	MeshUtil.add_static_box(map, Vector3(0.4, 3.4, 8), Color("3a3a3a"), Vector3(-35.2, 1.7, 38))
	MeshUtil.add_static_box(map, Vector3(3.2, 3.4, 0.4), Color("3a3a3a"), Vector3(-43.2, 1.7, 41.8))
	MeshUtil.add_static_box(map, Vector3(3.2, 3.4, 0.4), Color("3a3a3a"), Vector3(-36.8, 1.7, 41.8))
	var cell := Marker3D.new()
	cell.name = "PrisonCell"
	cell.position = Vector3(-40, 0.2, 38)
	cell.add_to_group("prison_cell")
	root.add_child(cell)
	var exit := Marker3D.new()
	exit.name = "PrisonExit"
	exit.position = Vector3(-40, 0.2, 30)
	exit.add_to_group("prison_exit")
	root.add_child(exit)
	var hatch: Area3D = HATCH.instantiate()
	hatch.position = Vector3(-40, 0.05, 38)
	root.add_child(hatch)
	var sign := Label3D.new()
	sign.text = "TOWN PRISON\n(please use the trap door)"
	sign.position = Vector3(-40, 5.2, 38)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 22
	map.add_child(sign)


static func _zones(root: Node3D) -> void:
	var spots := [Vector3(-12, 0, -12), Vector3(14, 0, 6), Vector3(0, 0, -28), Vector3(-20, 0, 12)]
	var i := 1
	for spot in spots:
		var zone: Area3D = ZONE.instantiate()
		zone.name = "SafeZone%s" % i
		zone.position = spot
		root.add_child(zone)
		i += 1


static func _people(root: Node3D) -> void:
	var civs := [
		[Vector3(-3, 0, 2), CivilianType.Job.SWEEP, CivilianType.Mood.FLEE],
		[Vector3(4, 0, -3), CivilianType.Job.CARRY, CivilianType.Mood.COWER],
		[Vector3(2, 0, 5), CivilianType.Job.NAP, CivilianType.Mood.COWER],
		[Vector3(-6, 0, -4), CivilianType.Job.ARGUE, CivilianType.Mood.FLEE],
		[Vector3(-5, 0, -5), CivilianType.Job.ARGUE, CivilianType.Mood.FLEE],
		[Vector3(10, 0, 2), CivilianType.Job.SWEEP, CivilianType.Mood.FLEE],
		[Vector3(-14, 0, 4), CivilianType.Job.CARRY, CivilianType.Mood.COWER],
		[Vector3(6, 0, -16), CivilianType.Job.SWEEP, CivilianType.Mood.FLEE],
		[Vector3(-8, 0, -18), CivilianType.Job.NAP, CivilianType.Mood.COWER],
		[Vector3(12, 0, 14), CivilianType.Job.CARRY, CivilianType.Mood.FLEE],
		[Vector3(-16, 0, -8), CivilianType.Job.SWEEP, CivilianType.Mood.COWER],
		[Vector3(0, 0, 12), CivilianType.Job.ARGUE, CivilianType.Mood.FLEE],
	]
	var spawned: Array = []
	var civ_i := 1
	for entry in civs:
		var civ = CIV.instantiate()
		civ.name = "Civilian%02d" % civ_i
		civ.position = entry[0]
		civ.job = entry[1]
		civ.mood = entry[2]
		root.add_child(civ)
		spawned.append(civ)
		civ_i += 1
	if spawned.size() >= 5:
		spawned[3].argue_partner = spawned[4]
		spawned[4].argue_partner = spawned[3]

	var patrols := [
		[Vector3(0, 0, 8), PackedVector3Array([Vector3(0, 0, 8), Vector3(10, 0, 8), Vector3(10, 0, -8), Vector3(0, 0, -8)])],
		[Vector3(-16, 0, 0), PackedVector3Array([Vector3(-16, 0, 0), Vector3(-16, 0, -16), Vector3(-6, 0, -16)])],
		[Vector3(16, 0, -4), PackedVector3Array([Vector3(16, 0, -4), Vector3(16, 0, 12), Vector3(6, 0, 12)])],
		[Vector3(-30, 0, 30), PackedVector3Array([Vector3(-30, 0, 30), Vector3(-40, 0, 30), Vector3(-40, 0, 22)])],
	]
	var guard_i := 1
	for entry in patrols:
		var guard = GUARD.instantiate()
		guard.name = "Guard%02d" % guard_i
		guard.position = entry[0]
		guard.patrol_points = entry[1]
		root.add_child(guard)
		guard_i += 1


static func _barrows(root: Node3D) -> void:
	var barrow_i := 1
	for pos in [Vector3(5, 0, 3), Vector3(-10, 0, -6), Vector3(8, 0, -20), Vector3(-18, 0, 8)]:
		var barrow: Node3D = BARROW.instantiate()
		barrow.name = "Wheelbarrow%02d" % barrow_i
		barrow.position = pos
		root.add_child(barrow)
		barrow_i += 1


static func _coins(root: Node3D) -> void:
	var placements := {
		"coin_forum_01": Vector3(3, 0, 3),
		"coin_forum_02": Vector3(-4, 0, 2),
		"coin_forum_03": Vector3(1, 0, -5),
		"coin_forum_04": Vector3(-2, 0, 6),
		"coin_street_n_01": Vector3(0, 0, -16),
		"coin_street_n_02": Vector3(-6, 0, -12),
		"coin_street_e_01": Vector3(14, 0, 0),
		"coin_street_e_02": Vector3(20, 0, 6),
		"coin_street_w_01": Vector3(-14, 0, 0),
		"coin_street_w_02": Vector3(-20, 0, -6),
		"coin_temple_01": Vector3(-3, 0, -26),
		"coin_temple_02": Vector3(3, 0, -30),
		"coin_rooftop_01": Vector3(16, 3.6, -22),
		"coin_garden_01": Vector3(14, 0, 6),
		"coin_prison_01": Vector3(-36, 0, 34),
		"coin_volcano_01": Vector3(4, 0, 48),
	}
	for coin_id in placements.keys():
		var coin = COIN.instantiate()
		coin.coin_id = coin_id
		coin.position = placements[coin_id]
		coin.name = coin_id
		root.add_child(coin)
