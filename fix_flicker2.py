import os

base   = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
scenes = os.path.join(base, "scenes")
scripts = os.path.join(base, "scripts")

# ── 1. CAMERA CONTROLLER SCRIPT (smooth lerp, no built-in smoothing) ──
camera_gd = """extends Camera2D

@export var target_path: NodePath
var target = null

func _ready():
    target = get_node_or_null(target_path)
    make_current()
    # Disable built-in smoothing - we do it manually
    position_smoothing_enabled = false

func _physics_process(_delta):
    if not target:
        return
    # Snap X to follow player exactly (no lag = no oscillation flicker)
    # Offset camera so player appears in left 1/3 of screen
    var dest_x = target.global_position.x + 280
    var dest_y = target.global_position.y - 120
    # Smooth Y gently, lock X precisely to stop horizontal jitter
    global_position.x = dest_x
    global_position.y = lerpf(global_position.y, dest_y, 0.12)
"""

# ── 2. PLAYER SCRIPT - bulletproof stun, no flicker ──
player_gd = """extends CharacterBody2D

const RUN_SPEED    = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY      = 1600.0

var state       = "run"
var stun_timer  = 0.0
var stunned     = false
var trail       = []

@onready var anim       = $Sprite2D
@onready var dust       = $DustParticles
@onready var col_normal = $ColNormal
@onready var col_slide  = $ColSlide
@onready var sfx_jump   = $SfxJump
@onready var sfx_hit    = $SfxHit

func _physics_process(delta):
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    # JUMP always works - also cancels stun
    if Input.is_action_just_pressed("jump") and is_on_floor():
        if stunned:
            _clear_stun()
        if state != "slide":
            velocity.y = JUMP_VELOCITY
            sfx_jump.play()

    if stunned:
        stun_timer -= delta
        velocity.x = 0.0
        if stun_timer <= 0.0:
            _clear_stun()
    else:
        velocity.x = RUN_SPEED

        if Input.is_action_pressed("slide") and is_on_floor():
            state = "slide"
            col_normal.disabled = true
            col_slide.disabled  = false
            dust.emitting       = true
        else:
            if state == "slide":
                state = "run"
                col_normal.disabled = false
                col_slide.disabled  = true
                dust.emitting       = false

        if not is_on_floor():
            state = "jump" if velocity.y < 0.0 else "fall"
        elif state != "slide":
            state = "run"

    _update_anim()
    move_and_slide()

    if global_position.y > 900 and state != "dead":
        state = "dead"
        set_physics_process(false)
        await get_tree().create_timer(0.4).timeout
        get_tree().reload_current_scene()
        return

    trail.append({"pos": global_position, "state": state})
    if trail.size() > 360:
        trail.pop_front()

func _update_anim():
    var rx = 0
    if stunned or state == "run":
        rx = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif state == "jump" or state == "fall":
        rx = 200
    elif state == "slide":
        rx = 300
    anim.region_rect = Rect2(rx, 0, 100, 100)

func stun():
    if stunned or state == "dead":
        return
    stunned    = true
    stun_timer = 1.2
    state      = "stun"
    sfx_hit.play()
    modulate   = Color(1.0, 0.35, 0.35)

func _clear_stun():
    stunned    = false
    stun_timer = 0.0
    state      = "run"
    modulate   = Color(1.0, 1.0, 1.0)
"""

# ── 3. PROJECT.GODOT - enable vsync + GL compat renderer to kill tearing ──
project_godot = """[application]
config/name="Vector Godot Runner Advanced V2"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.3", "GL Compatibility")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
window/vsync/vsync_mode=1

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"

[input]
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
slide={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
"""

# ── 4. MAIN.TSCN - camera is standalone node (NOT child of player) ──
main_tscn = """[gd_scene load_steps=9 format=3]

[ext_resource type="Script" path="res://scripts/LevelManager.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/sky.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/city_far.png" id="3"]
[ext_resource type="Texture2D" path="res://assets/city_mid.png" id="4"]
[ext_resource type="PackedScene" path="res://scenes/Player.tscn" id="5"]
[ext_resource type="PackedScene" path="res://scenes/Chaser.tscn" id="6"]
[ext_resource type="AudioStream" path="res://assets/coin.wav" id="7"]
[ext_resource type="Script" path="res://scripts/Camera.gd" id="8"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="ParallaxBackground" type="ParallaxBackground" parent="."]

[node name="SkyLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0, 0)

[node name="Sky" type="Sprite2D" parent="ParallaxBackground/SkyLayer"]
texture = ExtResource("2")
centered = false
position = Vector2(0, 0)
scale = Vector2(2, 1)

[node name="CityFarLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.08, 0)
motion_mirroring = Vector2(2560, 0)

[node name="CityFar" type="Sprite2D" parent="ParallaxBackground/CityFarLayer"]
texture = ExtResource("3")
centered = false

[node name="CityMidLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.22, 0)
motion_mirroring = Vector2(2560, 0)

[node name="CityMid" type="Sprite2D" parent="ParallaxBackground/CityMidLayer"]
texture = ExtResource("4")
centered = false

[node name="Player" parent="." instance=ExtResource("5")]
position = Vector2(300, 300)

[node name="Chaser" parent="." instance=ExtResource("6")]
position = Vector2(60, 300)
player_path = NodePath("../Player")

[node name="GameCamera" type="Camera2D" parent="."]
script = ExtResource("8")
target_path = NodePath("../Player")
zoom = Vector2(0.9, 0.9)
limit_bottom = 900
limit_right = 99999999

[node name="SfxCoin" type="AudioStreamPlayer" parent="."]
stream = ExtResource("7")

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="HUD" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Score" type="Label" parent="CanvasLayer/HUD"]
layout_mode = 0
offset_left = 16.0
offset_top = 14.0
offset_right = 700.0
offset_bottom = 52.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2
theme_override_font_sizes/font_size = 28
text = "Distance: 0m  Score: 0"
"""

with open(os.path.join(scripts, "Camera.gd"), "w", encoding="utf-8") as f:
    f.write(camera_gd)
print("Camera.gd written")

with open(os.path.join(scripts, "Player.gd"), "w", encoding="utf-8") as f:
    f.write(player_gd)
print("Player.gd written")

with open(os.path.join(base, "project.godot"), "w", encoding="utf-8") as f:
    f.write(project_godot.strip())
print("project.godot written (vsync enabled)")

with open(os.path.join(scenes, "Main.tscn"), "w", encoding="utf-8") as f:
    f.write(main_tscn.strip())
print("Main.tscn written (camera standalone)")

print("\nAll done! Reload in Godot and press Play.")
