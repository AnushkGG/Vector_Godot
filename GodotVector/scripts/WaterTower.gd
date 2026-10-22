extends Node2D

signal collectible_picked(kind: int)

const C_BLACK : Color = Color(0.04, 0.04, 0.05)
const COIN_SCENE : PackedScene = preload("res://scenes/Coin.tscn")
const COLLECTIBLE_SCRIPT : Script = preload("res://scripts/Collectible.gd")

@onready var climb_zone : Area2D = $ClimbZone
@onready var tank_top   : StaticBody2D = $TankTop
@onready var legs       : StaticBody2D = $Legs
@onready var side_stun  : Area2D = $SideStun

func _ready() -> void:
	add_to_group("water_towers")
	if climb_zone:
		climb_zone.add_to_group("climbable")
		climb_zone.set_meta("tank_top_y", -320.0)
		climb_zone.body_entered.connect(_on_climb_body_entered)
		climb_zone.body_exited.connect(_on_climb_body_exited)
	if legs:
		legs.add_to_group("tower_legs")
	if side_stun:
		side_stun.body_entered.connect(_on_side_body_entered)
	_spawn_tower_coins()

func _spawn_tower_coins() -> void:
	if has_node("TowerCoins"):
		return
	var container := Node2D.new()
	container.name = "TowerCoins"
	add_child(container)

	# 2 coins on top of the tank platform (y = -320.0)
	var tank_coins : Array[Vector2] = [
		Vector2(-22.0, -368.0),
		Vector2(22.0, -368.0)
	]
	for pos in tank_coins:
		_add_tower_coin(container, pos)

func _add_tower_coin(parent_node: Node2D, pos: Vector2) -> void:
	var coin := COIN_SCENE.instantiate() as Area2D
	if not coin.get_script():
		coin.set_script(COLLECTIBLE_SCRIPT)
	coin.position = pos
	coin.collision_layer = 0
	coin.collision_mask = 1
	coin.add_to_group("tower_coins")
	coin.picked_up.connect(_on_coin_picked)
	parent_node.add_child(coin)

func _on_coin_picked(kind: int) -> void:
	collectible_picked.emit(kind)
	if collectible_picked.get_connections().is_empty():
		var lm = get_tree().root.find_child("LevelManager", true, false)
		if not lm:
			lm = get_tree().root.find_child("Main", true, false)
		if lm and lm.has_method("_on_collectible"):
			lm._on_collectible(kind)

func _on_climb_body_entered(body: Node) -> void:
	if body.name == "Player" and body.has_method("enter_climb_zone"):
		body.enter_climb_zone(climb_zone)

func _on_climb_body_exited(body: Node) -> void:
	if body.name == "Player" and body.has_method("exit_climb_zone"):
		body.exit_climb_zone(climb_zone)

func _on_side_body_entered(body: Node) -> void:
	if body.name == "Player":
		var st = body.get("state")
		if st != "climb" and body.has_method("stun"):
			body.stun()

func _draw() -> void:
	# ── 1. Tank on top (y = -320 to -230) ─────────────────────────
	draw_rect(Rect2(-64.0, -320.0, 128.0, 8.0), C_BLACK)
	draw_rect(Rect2(-56.0, -323.0, 112.0, 3.0), C_BLACK)
	draw_rect(Rect2(-60.0, -312.0, 120.0, 82.0), C_BLACK)
	draw_rect(Rect2(-66.0, -230.0, 132.0, 8.0), C_BLACK)

	# ── 2. Lattice Tower Legs (y = -222 to 0.0) ───────────────────
	var leg_l := PackedVector2Array([
		Vector2(-55.0, -222.0),
		Vector2(-45.0, -222.0),
		Vector2(-53.0, 0.0),
		Vector2(-63.0, 0.0)
	])
	draw_colored_polygon(leg_l, C_BLACK)

	var leg_r := PackedVector2Array([
		Vector2(45.0, -222.0),
		Vector2(55.0, -222.0),
		Vector2(63.0, 0.0),
		Vector2(53.0, 0.0)
	])
	draw_colored_polygon(leg_r, C_BLACK)

	draw_rect(Rect2(-67.0, -4.5, 18.0, 4.5), C_BLACK)
	draw_rect(Rect2(49.0, -4.5, 18.0, 4.5), C_BLACK)

	# ── 3. Cross-Beams & X-Bracing ────────────────────────────────
	# Tier 1 Horizontal Beam (y = -142 to -134, thickness 8)
	draw_rect(Rect2(-53.0, -142.0, 106.0, 8.0), C_BLACK)

	# Tier 2 Horizontal Beam (y = -62 to -54, thickness 8)
	# Below this beam (y = -54 to 0) is the open 54-55 px slide gap
	draw_rect(Rect2(-57.0, -62.0, 114.0, 8.0), C_BLACK)

	# Tier 1 X-Brace (between y = -222 and y = -142)
	_draw_brace(Vector2(-48.0, -220.0), Vector2(48.0, -144.0), 7.0)
	_draw_brace(Vector2(48.0, -220.0), Vector2(-48.0, -144.0), 7.0)

	# Tier 2 X-Brace (between y = -134 and y = -62)
	_draw_brace(Vector2(-50.0, -132.0), Vector2(52.0, -64.0), 7.0)
	_draw_brace(Vector2(50.0, -132.0), Vector2(-52.0, -64.0), 7.0)

func _draw_brace(p1: Vector2, p2: Vector2, thickness: float) -> void:
	var dir   := (p2 - p1).normalized()
	var norm  := Vector2(-dir.y, dir.x) * (thickness * 0.5)
	var poly  := PackedVector2Array([
		p1 + norm,
		p2 + norm,
		p2 - norm,
		p1 - norm
	])
	draw_colored_polygon(poly, C_BLACK)
