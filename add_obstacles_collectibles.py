import os

base    = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
scripts = os.path.join(base, "scripts")
scenes  = os.path.join(base, "scenes")
assets  = os.path.join(base, "assets")

# ═══════════════════════════════════════════════════════════
# 1.  Collectible.gd  — coin / diamond Area2D pickup
# ═══════════════════════════════════════════════════════════
open(os.path.join(scripts,"Collectible.gd"),"w",encoding="utf-8").write("""extends Area2D

enum Type { COIN, DIAMOND }
@export var kind: Type = Type.COIN

signal picked_up(kind: int)   # emits Collectible.Type value

var _done := false

func _ready() -> void:
    body_entered.connect(_on_body)
    # bob animation
    var tw := create_tween()
    tw.set_loops()
    tw.tween_property(self, "position:y", position.y - 10.0, 0.7).set_ease(Tween.EASE_IN_OUT)
    tw.tween_property(self, "position:y", position.y,        0.7).set_ease(Tween.EASE_IN_OUT)

func _on_body(body: Node) -> void:
    if _done or body.name != "Player": return
    _done = true
    picked_up.emit(kind)
    _play_pickup()
    await get_tree().create_timer(0.25).timeout
    queue_free()

func _play_pickup() -> void:
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.18)
    tw.tween_property(self, "modulate:a", 0.0, 0.22)
""")

# ═══════════════════════════════════════════════════════════
# 2.  Spawner.gd  — obstacle + collectible spawner
# ═══════════════════════════════════════════════════════════
open(os.path.join(scripts,"Spawner.gd"),"w",encoding="utf-8").write("""extends Node2D
class_name Spawner

## Probability (0-1) that a gap will contain an obstacle
@export var spawn_rate: float = 0.78
## Minimum gap in pixels between obstacle clusters
@export var min_gap: float    = 520.0
## Maximum gap in pixels between obstacle clusters
@export var max_gap: float    = 1050.0
## Diamonds to place per run
@export var diamonds_per_run: int = 4

const GROUND_Y       := 560.0
const COIN_SCRIPT    := "res://scripts/Collectible.gd"
const COLL_COIN      := Collectible.Type.COIN
const COLL_DIAMOND   := Collectible.Type.DIAMOND

signal collectible_picked(kind: int, pos: Vector2)

enum ObsType { LOW_BLOCK, TALL_WALL, SLIDE_BEAM, SPIKE_PIT }

var _next_x        : float = 900.0
var _diamonds_left : int   = 0
var _player        : CharacterBody2D

# textures — reuse existing assets
var _tex_tall  := preload("res://assets/obs_tall.png")
var _tex_low   := preload("res://assets/obs_low.png")
var _tex_crate := preload("res://assets/obs_crate.png")

func _ready() -> void:
    _diamonds_left = diamonds_per_run

func _process(_delta: float) -> void:
    if not _player:
        _player = get_node_or_null("../Player")
        if not _player: return
    if _player.get("state") == "dead" or _player.get("state") == null:
        return
    if _player.global_position.x + 1800.0 > _next_x:
        if randf() < spawn_rate:
            _spawn_cluster(_next_x)
        _next_x += randf_range(min_gap, max_gap)

# ── obstacle cluster ────────────────────────────────────────
func _spawn_cluster(cx: float) -> void:
    var kind: ObsType = ObsType.values()[randi() % 4]
    var obs: Node2D = _make_obstacle(kind, cx)
    add_child(obs)

    # place coins relative to this obstacle
    match kind:
        ObsType.LOW_BLOCK:
            _spawn_coin_arc(cx, GROUND_Y - 110.0, 6)          # arc over the block
        ObsType.TALL_WALL:
            _spawn_coin_line(cx + 160.0, GROUND_Y - 60.0, 5)  # coins after wall (reward)
        ObsType.SLIDE_BEAM:
            _spawn_coin_line(cx + 20.0, GROUND_Y - 35.0, 5)   # low line to slide through
        ObsType.SPIKE_PIT:
            _spawn_coin_line(cx - 120.0, GROUND_Y - 80.0, 4)  # coins before pit (bait)

    # diamond on tall wall or spike pit (harder route)
    if _diamonds_left > 0 and kind in [ObsType.TALL_WALL, ObsType.SPIKE_PIT] and randf() > 0.45:
        _spawn_diamond(cx + 80.0, GROUND_Y - 240.0)
        _diamonds_left -= 1

# ── 4 obstacle types ────────────────────────────────────────
func _make_obstacle(kind: ObsType, cx: float) -> Node2D:
    match kind:
        ObsType.LOW_BLOCK:   return _solid_box(cx, GROUND_Y - 50.0,  90.0, 100.0, _tex_crate)
        ObsType.TALL_WALL:   return _solid_box(cx, GROUND_Y - 120.0, 55.0, 240.0, _tex_tall)
        ObsType.SLIDE_BEAM:  return _slide_beam(cx)
        ObsType.SPIKE_PIT:   return _spike_pit(cx)
    return _solid_box(cx, GROUND_Y - 50.0, 90.0, 100.0, _tex_crate)

func _solid_box(cx:float, cy:float, w:float, h:float, tex:Texture2D) -> StaticBody2D:
    # StaticBody2D = solid: player physically stops; can jump onto top (climbable)
    var obs := StaticBody2D.new()
    obs.position = Vector2(cx, cy)
    var sp := Sprite2D.new()
    sp.texture = tex
    # scale sprite to fill w x h
    var ts := tex.get_size()
    sp.scale   = Vector2(w / ts.x, h / ts.y)
    obs.add_child(sp)
    var col := CollisionShape2D.new()
    var shp := RectangleShape2D.new()
    shp.size = Vector2(w, h)
    col.shape = shp
    obs.add_child(col)
    return obs

func _slide_beam(cx: float) -> Node2D:
    # Overhead beam: player must SLIDE under it.
    # Architecture: two solid pillars + horizontal beam on top, open gap at bottom.
    # Gap height = 52px  (fits sliding player ~40px tall, blocks running player ~80px).
    var root := Node2D.new()
    root.position = Vector2(cx, GROUND_Y)

    const BEAM_W    := 220.0
    const PILLAR_W  := 22.0
    const TOTAL_H   := 120.0
    const GAP_H     := 52.0          # clearance at bottom for sliding
    const BEAM_THICK := TOTAL_H - GAP_H   # solid part from top

    # Overhead beam (solid — blocks standing player)
    var beam := StaticBody2D.new()
    beam.position = Vector2(BEAM_W * 0.5, -GAP_H - BEAM_THICK * 0.5)
    root.add_child(beam)
    var b_spr := Sprite2D.new()
    b_spr.texture = _tex_low
    var bt := _tex_low.get_size()
    b_spr.scale = Vector2(BEAM_W / bt.x, BEAM_THICK / bt.y)
    beam.add_child(b_spr)
    var b_col := CollisionShape2D.new()
    var b_shp := RectangleShape2D.new()
    b_shp.size = Vector2(BEAM_W, BEAM_THICK)
    b_col.shape = b_shp
    beam.add_child(b_col)

    # Stun trigger in the gap — fires if player is NOT sliding
    var stun_area := Area2D.new()
    stun_area.position = Vector2(BEAM_W * 0.5, -GAP_H * 0.5)
    root.add_child(stun_area)
    var s_col := CollisionShape2D.new()
    var s_shp := RectangleShape2D.new()
    s_shp.size = Vector2(BEAM_W, GAP_H)
    s_col.shape = s_shp
    stun_area.add_child(s_col)
    stun_area.body_entered.connect(_on_beam_enter.bind(stun_area))

    return root

func _on_beam_enter(body: Node, _area) -> void:
    if body.name == "Player" and body.get("state") != "slide":
        body.stun()

func _spike_pit(cx: float) -> Node2D:
    # Wide Area2D: instant kill on contact (player falls or dies)
    const PIT_W := 160.0
    const PIT_H := 30.0
    var area := Area2D.new()
    area.position = Vector2(cx + PIT_W * 0.5, GROUND_Y - PIT_H * 0.5)

    # Visual: red spikes drawn via line sprite
    var sp := Sprite2D.new()
    # reuse obs_tall but tint red and squish flat
    sp.texture  = _tex_tall
    var ts := _tex_tall.get_size()
    sp.scale    = Vector2(PIT_W / ts.x, PIT_H / ts.y)
    sp.modulate = Color(1.0, 0.15, 0.15)
    area.add_child(sp)

    var col := CollisionShape2D.new()
    var shp := RectangleShape2D.new()
    shp.size = Vector2(PIT_W, PIT_H)
    col.shape = shp
    area.add_child(col)
    area.body_entered.connect(_on_spike.bind(area))
    return area

func _on_spike(body: Node, _area) -> void:
    if body.name == "Player" and body.get("state") != "dead":
        body.set("state", "dead")
        body.set_physics_process(false)
        get_tree().create_timer(0.4).timeout.connect(
            func(): if is_instance_valid(body): body.died.emit()
        )

# ── collectible helpers ─────────────────────────────────────
func _make_collectible(x:float, y:float, kind:Collectible.Type) -> Collectible:
    var c := Collectible.new()
    c.kind     = kind
    c.position = Vector2(x, y)
    c.picked_up.connect(_on_pickup)
    var sp := Sprite2D.new()
    sp.texture  = preload("res://assets/coin.png") if kind == COLL_COIN \
                  else preload("res://assets/diamond.png")
    if kind == COLL_DIAMOND:
        sp.scale = Vector2(1.6, 1.6)
    c.add_child(sp)
    var col := CollisionShape2D.new()
    var shp := CircleShape2D.new()
    shp.radius = 14.0 if kind == COLL_COIN else 20.0
    col.shape  = shp
    c.add_child(col)
    return c

func _spawn_coin_line(start_x:float, y:float, count:int) -> void:
    for i in range(count):
        add_child(_make_collectible(start_x + i * 36.0, y, COLL_COIN))

func _spawn_coin_arc(peak_x:float, peak_y:float, count:int) -> void:
    # Parabolic arc centred on peak_x — mirrors the player's jump trajectory
    var half := (count - 1) * 0.5
    for i in range(count):
        var t   : float = (i - half) / max(half, 1.0)   # -1 .. +1
        var ax  : float = peak_x + t * 110.0
        var ay  : float = peak_y + t * t * 90.0          # parabola opens downward? No: opens up
        add_child(_make_collectible(ax, ay, COLL_COIN))

func _spawn_diamond(x:float, y:float) -> void:
    add_child(_make_collectible(x, y, COLL_DIAMOND))

func _on_pickup(kind: int, _src: Collectible) -> void:
    # Re-emit with world position so LevelManager can update HUD
    pass   # connected externally; signal already carries kind

# allow external connection
func connect_pickup(cb: Callable) -> void:
    # walk all existing + future — just connect on _make_collectible instead
    pass
""")
print("Spawner.gd written")

# ═══════════════════════════════════════════════════════════
# 3.  Patch LevelManager.gd
#     • remove old obstacle spawning (keep ground chunks)
#     • add coin/diamond wallet + HUD
#     • fix ground Y to constant so Spawner can rely on it
#     • connect Spawner signals
# ═══════════════════════════════════════════════════════════
lm = open(os.path.join(scripts,"LevelManager.gd"), encoding="utf-8").read()

# Strip the old _make_obs helper and replace spawn_chunk with ground-only version
# Also add coin/diamond tracking

old_onready_block = """@onready var player = $Player
@onready var hud_score = $CanvasLayer/HUD/Score
@onready var sfx_coin  = $SfxCoin
@onready var ui        = $UI"""

new_onready_block = """@onready var player      = $Player
@onready var hud_score   = $CanvasLayer/HUD/Score
@onready var hud_coins   = $CanvasLayer/HUD/Coins
@onready var hud_diamonds = $CanvasLayer/HUD/Diamonds
@onready var sfx_coin    = $SfxCoin
@onready var ui          = $UI
@onready var spawner     = $Spawner

var coins_level: int    = 0
var diamonds_level: int = 0
var coin_wallet: int    = 0"""

lm = lm.replace(old_onready_block, new_onready_block)

# Fix chunk_x start and remove random ground Y
lm = lm.replace("var chunk_x  = 2000.0", "var chunk_x  = 0.0\nconst GROUND_Y := 560.0")

# Replace _ready to connect spawner
old_ready = """func _ready() -> void:
    get_tree().paused = true
    ui.start_pressed.connect(_on_start_pressed)
    ui.restart_pressed.connect(_on_restart_pressed)
    player.died.connect(_on_player_died)"""

new_ready = """func _ready() -> void:
    get_tree().paused = true
    ui.start_pressed.connect(_on_start_pressed)
    ui.restart_pressed.connect(_on_restart_pressed)
    player.died.connect(_on_player_died)
    spawner.collectible_picked.connect(_on_collectible)

func _on_collectible(kind: int) -> void:
    if kind == Collectible.Type.COIN:
        coins_level += 1
        coin_wallet += 1
        sfx_coin.play()
    else:
        diamonds_level += 1
    _update_hud()

func _update_hud() -> void:
    hud_coins.text    = "Coins: %d" % coins_level
    hud_diamonds.text = "Diamonds: %d" % diamonds_level"""

lm = lm.replace(old_ready, new_ready)

# Replace spawn_chunk with ground-only version + remove _make_obs
# Find and replace the whole spawn_chunk + _make_obs block
import re

# Replace everything from spawn_chunk declaration to end of _make_obs
new_spawn = """func spawn_chunk() -> void:
    var root := Node2D.new()
    root.position = Vector2(chunk_x, 0)
    add_child(root)

    var gb := StaticBody2D.new()
    gb.position = Vector2(0, GROUND_Y)
    root.add_child(gb)
    var g_spr := Sprite2D.new()
    g_spr.texture  = ground_tex
    g_spr.position = Vector2(500, 60)
    g_spr.scale    = Vector2(2.0, 1.0)
    gb.add_child(g_spr)
    var g_col := CollisionShape2D.new()
    var g_shp := RectangleShape2D.new()
    g_shp.size    = Vector2(1000, 120)
    g_col.shape   = g_shp
    g_col.position = Vector2(500, 60)
    gb.add_child(g_col)

    chunk_x += 1000

"""

# Remove old spawn_chunk, _make_obs, and any coin spawning from LevelManager
# Use regex to remove from spawn_chunk to end of file (before show_popup)
lm = re.sub(
    r'func spawn_chunk.*?(?=func show_popup)',
    new_spawn,
    lm,
    flags=re.DOTALL
)

# Also remove old coin/obs texture preloads — no longer needed in LevelManager
for old in ["var obs_tall_tex", "var obs_low_tex", "var obs_crate_tex", "var coin_tex"]:
    lm = re.sub(r'var obs_.*?_tex\s*=.*?\n', '', lm)
    lm = re.sub(r'var coin_tex\s*=.*?\n', '', lm)

open(os.path.join(scripts,"LevelManager.gd"), "w", encoding="utf-8").write(lm)
print("LevelManager.gd patched")

# ═══════════════════════════════════════════════════════════
# 4.  Patch Spawner.gd — fix signal emission (use collectible_picked directly)
#     The signal needs to be emitted from _on_pickup properly
# ═══════════════════════════════════════════════════════════
spawner_src = open(os.path.join(scripts,"Spawner.gd"), encoding="utf-8").read()
spawner_src = spawner_src.replace(
    "func _on_pickup(kind: int, _src: Collectible) -> void:\n    # Re-emit with world position so LevelManager can update HUD\n    pass   # connected externally; signal already carries kind",
    "func _on_pickup(kind: int) -> void:\n    collectible_picked.emit(kind)"
)
spawner_src = spawner_src.replace(
    "    c.picked_up.connect(_on_pickup)",
    "    c.picked_up.connect(func(k): collectible_picked.emit(k))"
)
open(os.path.join(scripts,"Spawner.gd"), "w", encoding="utf-8").write(spawner_src)

# ═══════════════════════════════════════════════════════════
# 5.  Main.tscn — add Spawner node + HUD coin/diamond labels
# ═══════════════════════════════════════════════════════════
main = open(os.path.join(scenes,"Main.tscn"), encoding="utf-8").read()

# Add Spawner ext_resource
spawner_ext = '[ext_resource type="Script" path="res://scripts/Spawner.gd" id="spawner_scr"]'
if 'Spawner.gd' not in main:
    # Insert after last ext_resource line
    last_ext_end = main.rfind('\n', 0, main.rfind('[ext_resource')) 
    last_ext_end = main.find('\n', main.rfind('[ext_resource')) + 1
    main = main[:last_ext_end] + spawner_ext + "\n" + main[last_ext_end:]

# Add Spawner node before UI node (or before SfxCoin)
spawner_node = """
[node name="Spawner" type="Node2D" parent="."]
script = ExtResource("spawner_scr")
spawn_rate = 0.78
min_gap = 520.0
max_gap = 1050.0
diamonds_per_run = 4
"""
if '"Spawner"' not in main:
    main = main.replace(
        '[node name="SfxCoin"',
        spawner_node + '\n[node name="SfxCoin"'
    )

# Add HUD coin/diamond labels
hud_additions = """
[node name="Coins" type="Label" parent="CanvasLayer/HUD"]
layout_mode = 0
offset_left = 16.0
offset_top = 50.0
offset_right = 400.0
offset_bottom = 84.0
theme_override_colors/font_color = Color(1, 0.9, 0.1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2
theme_override_font_sizes/font_size = 22
text = "Coins: 0"

[node name="Diamonds" type="Label" parent="CanvasLayer/HUD"]
layout_mode = 0
offset_left = 16.0
offset_top = 80.0
offset_right = 400.0
offset_bottom = 114.0
theme_override_colors/font_color = Color(0.7, 0.4, 1.0, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2
theme_override_font_sizes/font_size = 22
text = "Diamonds: 0"
"""
if '"Diamonds"' not in main:
    # Insert after the Score label node
    score_end = main.find('text = "Distance: 0m  Score: 0"') + len('text = "Distance: 0m  Score: 0"')
    main = main[:score_end] + "\n" + hud_additions + main[score_end:]

open(os.path.join(scenes,"Main.tscn"), "w", encoding="utf-8").write(main)
print("Main.tscn patched (Spawner + HUD labels)")

# ═══════════════════════════════════════════════════════════
# 6.  Diamond asset (magenta rotated square)
# ═══════════════════════════════════════════════════════════
from PIL import Image, ImageDraw
d_img = Image.new('RGBA', (32, 32), (0,0,0,0))
dd = ImageDraw.Draw(d_img)
dd.polygon([(16,1),(31,16),(16,31),(1,16)], fill=(190,80,255,255))
dd.line([(16,1),(31,16),(16,31),(1,16),(16,1)], fill=(255,255,255,200), width=2)
dd.line([(16,1),(16,31)], fill=(230,150,255,120), width=1)
dd.line([(1,16),(31,16)], fill=(230,150,255,120), width=1)
d_img.save(os.path.join(assets,"diamond.png"))
print("diamond.png generated")
print("\nDone. Reload All in Godot -> Play")
