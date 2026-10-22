import os

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"

# --- 1. PLAYER.GD (Record Trail) ---
player_gd = """extends CharacterBody2D

const RUN_SPEED = 500.0
const JUMP_VELOCITY = -700.0
const GRAVITY = 1600.0

var state = "run"
var stun_timer = 0.0

# GHOST TRAIL DATA
var trail = [] # Array of dictionaries: {pos, state}

@onready var anim = $Sprite2D
@onready var dust = $DustParticles
@onready var col_normal = $ColNormal
@onready var col_slide = $ColSlide
@onready var sfx_jump = $SfxJump
@onready var sfx_hit = $SfxHit

func _physics_process(delta):
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    if state == "stun":
        stun_timer -= delta
        velocity.x = RUN_SPEED * 0.4
        if stun_timer <= 0:
            state = "run"
    else:
        velocity.x = RUN_SPEED
        if Input.is_action_pressed("slide") and is_on_floor():
            state = "slide"
            col_normal.disabled = true
            col_slide.disabled = false
            dust.emitting = true
        else:
            if state == "slide":
                state = "run"
                col_normal.disabled = false
                col_slide.disabled = true
                dust.emitting = false
                
        if Input.is_action_just_pressed("jump") and is_on_floor() and state != "slide":
            velocity.y = JUMP_VELOCITY
            sfx_jump.play()
            
        if not is_on_floor():
            if velocity.y < 0:
                state = "jump"
            else:
                state = "fall"
        elif state != "slide":
            state = "run"

    if state == "run":
        anim.region_rect.position.x = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif state == "jump" or state == "fall":
        anim.region_rect.position.x = 200
    elif state == "slide":
        anim.region_rect.position.x = 300
        
    move_and_slide()
    
    # RECORD TRAIL EVERY FRAME
    trail.append({"pos": global_position, "state": state})
    if trail.size() > 300: # Keep about 5 seconds at 60fps
        trail.pop_front()

func stun():
    if state != "stun":
        state = "stun"
        stun_timer = 1.0
        sfx_hit.play()
        modulate = Color(1, 0.5, 0.5)
        await get_tree().create_timer(1.0).timeout
        modulate = Color(1, 1, 1)
"""
with open(os.path.join(base_dir, "scripts", "Player.gd"), "w") as f:
    f.write(player_gd)

# --- 2. CHASER.GD (Ghost Follower) ---
chaser_gd = """extends Node2D # Changed to Node2D since physics is no longer needed

@export var player_path: NodePath
@onready var player = get_node(player_path)
@onready var anim = $Sprite2D

var delay_frames = 60 # 1 second behind
var current_catch_up = 0.0

func _physics_process(delta):
    if not player or player.trail.size() == 0:
        return
        
    # If player is stunned, reduce delay to catch up!
    if player.state == "stun":
        delay_frames = max(10, delay_frames - 1)
    else:
        # Slowly revert to normal delay
        if delay_frames < 60:
            current_catch_up += delta
            if current_catch_up > 0.1:
                delay_frames += 1
                current_catch_up = 0
                
    var target_idx = player.trail.size() - delay_frames - 1
    if target_idx < 0:
        target_idx = 0
        
    var data = player.trail[target_idx]
    global_position = data["pos"]
    var p_state = data["state"]
    
    # Mirror animation
    if p_state == "run" or p_state == "stun":
        anim.region_rect.position.x = (Engine.get_frames_drawn() / 10 % 2) * 100
    elif p_state == "jump" or p_state == "fall":
        anim.region_rect.position.x = 200
    elif p_state == "slide":
        anim.region_rect.position.x = 300
        
    # Game Over Condition
    if global_position.distance_to(player.global_position) < 40:
        get_tree().reload_current_scene()
"""
with open(os.path.join(base_dir, "scripts", "Chaser.gd"), "w") as f:
    f.write(chaser_gd)

# --- 3. LEVELMANAGER.GD (Popups) ---
level_gd = """extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D
@onready var hud_score = $CanvasLayer/HUD/Score
@onready var sfx_coin = $SfxCoin
var chunk_x = 2000.0
var score = 0
var distance = 0.0

var ground_tex = preload("res://assets/ground.png")
var obs_tall_tex = preload("res://assets/obs_tall.png")
var obs_low_tex = preload("res://assets/obs_low.png")
var obs_crate_tex = preload("res://assets/obs_crate.png")
var coin_tex = preload("res://assets/coin.png")

func _process(_delta):
    if player:
        camera.global_position.x = player.global_position.x + 300
        distance = player.global_position.x / 100.0
        hud_score.text = "Distance: %dm | Score: %d" % [int(distance), score]
        
        if camera.global_position.x + 1500 > chunk_x:
            spawn_chunk()

func spawn_chunk():
    var chunk = StaticBody2D.new()
    chunk.position = Vector2(chunk_x, randf_range(500, 650))
    add_child(chunk)
    
    var spr = Sprite2D.new()
    spr.texture = ground_tex
    spr.position = Vector2(500, 100)
    spr.scale = Vector2(2.0, 1.0)
    chunk.add_child(spr)
    
    var col = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(1000, 200)
    col.shape = shape
    col.position = Vector2(500, 100)
    chunk.add_child(col)
    
    if randf() > 0.5:
        var type = randi() % 3
        var obs = Area2D.new()
        obs.position = Vector2(randf_range(200, 800), 0)
        var o_spr = Sprite2D.new()
        var o_col = CollisionShape2D.new()
        var o_shape = RectangleShape2D.new()
        if type == 0:
            o_spr.texture = obs_tall_tex
            o_spr.position = Vector2(0, -60)
            o_shape.size = Vector2(30, 120)
        elif type == 1:
            o_spr.texture = obs_low_tex
            o_spr.position = Vector2(0, -40)
            o_shape.size = Vector2(200, 80)
        else:
            o_spr.texture = obs_crate_tex
            o_spr.position = Vector2(0, -30)
            o_shape.size = Vector2(60, 60)
        o_col.shape = o_shape
        o_col.position = o_spr.position
        obs.add_child(o_spr)
        obs.add_child(o_col)
        obs.body_entered.connect(_on_obstacle_hit.bind(obs))
        obs.body_exited.connect(_on_obstacle_clear.bind(obs)) # For +100 popup
        chunk.add_child(obs)
        
    for i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(randf_range(100, 900), -randf_range(50, 150))
        var c_spr = Sprite2D.new()
        c_spr.texture = coin_tex
        var c_col = CollisionShape2D.new()
        var c_shape = CircleShape2D.new()
        c_shape.radius = 16
        c_col.shape = c_shape
        coin.add_child(c_spr)
        coin.add_child(c_col)
        coin.body_entered.connect(_on_coin_hit.bind(coin))
        chunk.add_child(coin)
        
    chunk_x += 1000 + randf_range(150, 300)

func show_popup(text_str, pos):
    var lbl = Label.new()
    lbl.text = text_str
    lbl.global_position = pos + Vector2(-20, -50)
    lbl.add_theme_color_override("font_color", Color(1,1,0))
    lbl.add_theme_font_size_override("font_size", 24)
    add_child(lbl)
    var tw = create_tween()
    tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 100, 1.0)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
    tw.tween_callback(lbl.queue_free)

func _on_obstacle_hit(body, obs_node):
    if body.name == "Player":
        body.stun()

func _on_obstacle_clear(body, obs_node):
    if body.name == "Player" and body.state != "stun":
        score += 50
        show_popup("Swallow\\n+50", body.global_position)

func _on_coin_hit(body, coin_node):
    if body.name == "Player":
        score += 10
        sfx_coin.play()
        show_popup("+10", coin_node.global_position)
        coin_node.queue_free()
"""
with open(os.path.join(base_dir, "scripts", "LevelManager.gd"), "w") as f:
    f.write(level_gd)

# --- 4. MAIN.TSCN (Update Background) ---
import re
with open(os.path.join(base_dir, "scenes", "Main.tscn"), "r") as f:
    main_tscn = f.read()

# Replace SkyLayer texture with our new vector_bg.png
main_tscn = main_tscn.replace('path="res://assets/sky.png"', 'path="res://assets/vector_bg.png"')
with open(os.path.join(base_dir, "scenes", "Main.tscn"), "w") as f:
    f.write(main_tscn)

# --- 5. CHASER.TSCN (Remove Physics Nodes) ---
chaser_tscn = """[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/Chaser.gd" id="1_scr"]
[ext_resource type="Texture2D" path="res://assets/chaser_sheet.png" id="2_tex"]

[node name="Chaser" type="Node2D"]
script = ExtResource("1_scr")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")
region_enabled = true
region_rect = Rect2(0, 0, 100, 100)
"""
with open(os.path.join(base_dir, "scenes", "Chaser.tscn"), "w") as f:
    f.write(chaser_tscn)

print("Upgrade complete.")
