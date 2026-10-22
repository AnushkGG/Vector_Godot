import os, shutil, math, struct, wave
from PIL import Image, ImageDraw, ImageFilter

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets_dir = os.path.join(base_dir, "assets")
scenes_dir = os.path.join(base_dir, "scenes")
scripts_dir = os.path.join(base_dir, "scripts")

os.makedirs(assets_dir, exist_ok=True)
os.makedirs(scenes_dir, exist_ok=True)
os.makedirs(scripts_dir, exist_ok=True)

# Clear Godot cache
godot_cache = os.path.join(base_dir, ".godot")
if os.path.exists(godot_cache):
    shutil.rmtree(godot_cache)

# -------------------------------------------------------
# ASSETS MATCHING THE C++ GAME
# -------------------------------------------------------

# 1. Sky - light blue with white horizon strip (exactly as C++ code)
sky = Image.new('RGB', (1280, 720))
draw = ImageDraw.Draw(sky)
# Sky blue background
for y in range(720):
    t = y / 720.0
    r = int(100 + (220 - 100) * t)
    g = int(180 + (240 - 180) * t)
    b = int(255 + (255 - 255) * t)
    draw.line([(0, y), (1280, y)], fill=(r, g, b))
# Bright horizon strip (matches C++ white bar from y=225 to GROUND_Y-1)
for y in range(450, 590):
    alpha = 1.0 - (y - 450) / 140.0
    r = int(255 * alpha + (100 + (220-100)*(y/720)) * (1-alpha))
    g = int(255 * alpha + (180 + (240-180)*(y/720)) * (1-alpha))
    b = 255
    draw.line([(0, y), (1280, y)], fill=(min(255,r), min(255,g), min(255,b)))
sky.save(os.path.join(assets_dir, "sky.png"))
print("sky.png generated")

# 2. City far background - grey buildings with white windows
def draw_city_far(path):
    heights = [95,135,170,115,145,185,120,155,100,175,130,165,110,190,125,150]
    img = Image.new('RGB', (2560, 720), (130, 160, 190))
    draw = ImageDraw.Draw(img)
    spacing = 185
    for i in range(15):
        h = heights[i % 16]
        x = i * spacing
        w = 125 + (i * 19 % 45)
        shade = i % 3
        color = (180,185,190) if shade==0 else (160,165,170) if shade==1 else (100,105,110)
        draw.rectangle([x, 720-h, x+w, 720], fill=color)
        draw.line([x, 720-h, x+w, 720-h], fill=(80,80,80))
        # Windows
        cols = 4 if w >= 150 else 3
        rows = max(2, int((h-15)//28))
        for row in range(rows):
            wy = 720 - h + 14 + row*26
            if wy+10 >= 716: break
            for col in range(1, cols+1):
                cx = x + col * w//(cols+1)
                draw.rectangle([cx-5, wy, cx+5, wy+10], fill=(255,240,180))
    img.save(path)

draw_city_far(os.path.join(assets_dir, "city_far.png"))
print("city_far.png generated")

# 3. City mid background - darker with more detail
def draw_city_mid(path):
    heights = [130,175,210,155,185,225,160,195,140,215,170,205,150,230,165,190]
    img = Image.new('RGBA', (2560, 720), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    spacing = 185
    for i in range(15):
        h = heights[i % 16]
        x = i * spacing
        w = 100 + (i * 23 % 55)
        color = (60,65,75,220) if i%2==0 else (45,50,60,220)
        draw.rectangle([x, 720-h, x+w, 720], fill=color)
        draw.line([x, 720-h, x+w, 720-h], fill=(40,40,50,255))
        # Glowing windows
        cols = 3
        rows = max(3, int((h-15)//24))
        import random; random.seed(i*7)
        for row in range(rows):
            wy = 720 - h + 12 + row*22
            if wy+8 >= 716: break
            for col in range(1, cols+1):
                cx = x + col * w//(cols+1)
                if random.random() > 0.35:
                    draw.rectangle([cx-4, wy, cx+4, wy+8], fill=(255,210,100,255))
    img.save(path)

draw_city_mid(os.path.join(assets_dir, "city_mid.png"))
print("city_mid.png generated")

# 4. Black ground tile (rooftop)
g_img = Image.new('RGBA', (500, 60), (0,0,0,0))
gd = ImageDraw.Draw(g_img)
gd.rectangle([0,0,500,60], fill=(15,15,15,255))
gd.line([0,0,500,0], fill=(60,60,60,255), width=2)  # top edge
gd.line([0,1,500,1], fill=(40,40,40,255), width=1)
# Parapet detail lines (matching C++ drawForegroundBuilding)
gd.line([0,7,500,7], fill=(50,50,50,255))
gd.line([0,10,500,10], fill=(40,40,40,255))
for px in range(6, 500, 12):
    gd.line([px,2,px,6], fill=(50,50,50,255))
g_img.save(os.path.join(assets_dir, "ground.png"))

# 5. Obstacles (matching C++ OB_TANK, OB_CRATE, OB_FENCE)
# Water tower (OB_TANK, halfW=20, h=58)
tank = Image.new('RGBA', (44, 62), (0,0,0,0))
td = ImageDraw.Draw(tank)
# Lattice legs
td.rectangle([3,40,6,62], fill=(0,0,0,255))
td.rectangle([38,40,41,62], fill=(0,0,0,255))
td.line([6,40,38,62], fill=(0,0,0,255), width=2)
td.line([38,40,6,62], fill=(0,0,0,255), width=2)
td.line([3,51,41,51], fill=(0,0,0,255))
# Platform under barrel
td.rectangle([0,36,44,40], fill=(0,0,0,255))
# Barrel
td.polygon([(4,0),(40,0),(44,7),(0,7)], fill=(0,0,0,255))
td.rectangle([0,6,44,38], fill=(0,0,0,255))
td.line([0,14,44,14], fill=(30,30,30,255))
td.line([0,26,44,26], fill=(30,30,30,255))
td.line([10,7,10,36], fill=(30,30,30,255))
td.line([22,7,22,36], fill=(30,30,30,255))
td.line([34,7,34,36], fill=(30,30,30,255))
tank.save(os.path.join(assets_dir, "obs_tall.png"))

# Crate (OB_CRATE, halfW=15, h=30)
crate = Image.new('RGBA', (32, 32), (0,0,0,0))
cd = ImageDraw.Draw(crate)
cd.rectangle([0,0,32,32], fill=(0,0,0,255))
cd.rectangle([3,3,29,29], outline=(40,40,40,255), width=1)
cd.line([3,3,29,29], fill=(40,40,40,255))
cd.line([29,3,3,29], fill=(40,40,40,255))
cd.line([3,16,29,16], fill=(40,40,40,255))
crate.save(os.path.join(assets_dir, "obs_crate.png"))

# Fence (OB_FENCE, halfW=30, h=20)
fence = Image.new('RGBA', (62, 22), (0,0,0,0))
fd = ImageDraw.Draw(fence)
# Top rail (3px thick)
fd.rectangle([0,0,62,2], fill=(0,0,0,255))
# Middle rail
fd.line([0,11,62,11], fill=(0,0,0,255))
# Posts left and right
fd.rectangle([0,0,2,22], fill=(0,0,0,255))
fd.rectangle([60,0,62,22], fill=(0,0,0,255))
# Chain link
for x in range(0, 55, 10):
    fd.line([x,22,x+10,0], fill=(0,0,0,255))
    fd.line([x+10,22,x,0], fill=(0,0,0,255))
# Barbed wire ticks
for x in range(6, 62, 8):
    fd.line([x-2,0,x+2,4], fill=(50,50,50,255))
fence.save(os.path.join(assets_dir, "obs_low.png"))

# 6. Coin
c_img = Image.new('RGBA', (24, 24), (0,0,0,0))
ImageDraw.Draw(c_img).ellipse([2,2,22,22], fill=(255,215,0,255), outline=(255,255,255,255), width=2)
c_img.save(os.path.join(assets_dir, "coin.png"))

# 7. Diamond (magenta, matching C++ DIAMOND=LIGHTMAGENTA)
d_img = Image.new('RGBA', (24, 24), (0,0,0,0))
ImageDraw.Draw(d_img).polygon([(12,1),(23,12),(12,23),(1,12)], fill=(255,100,255,255))
ImageDraw.Draw(d_img).line([(12,1),(23,12),(12,23),(1,12),(12,1)], fill=(255,255,255,255), width=1)
d_img.save(os.path.join(assets_dir, "diamond.png"))

# 8. Dust particle
p_img = Image.new('RGBA', (8,8), (0,0,0,0))
ImageDraw.Draw(p_img).ellipse([1,1,7,7], fill=(200,200,200,180))
p_img.save(os.path.join(assets_dir, "particle.png"))

# 9. Stickman sprite sheets (player and chaser)
# 4 frames: run1, run2, jump, slide — matching C++ IK poses
def draw_stickman_frame(action, color=(0,0,0,255)):
    img = Image.new('RGBA', (100, 120), (0,0,0,0))
    d = ImageDraw.Draw(img)
    W = 5  # line width for muscles
    if action == "run1":
        # Head
        d.ellipse([46,4,62,20], fill=color)
        # Body (leaning forward)
        d.line([54,20,50,55], fill=color, width=6)
        # Front leg (knee forward)
        d.line([50,55,42,80], fill=color, width=W)
        d.line([42,80,55,105], fill=color, width=W)
        # Back leg (knee back, foot back)
        d.line([50,55,58,72], fill=color, width=W)
        d.line([58,72,44,88], fill=color, width=W)
        # Front arm (swinging back)
        d.line([50,30,36,45], fill=color, width=4)
        d.line([36,45,28,55], fill=color, width=4)
        # Back arm (forward)
        d.line([50,30,65,40], fill=color, width=4)
        d.line([65,40,72,52], fill=color, width=4)
    elif action == "run2":
        d.ellipse([44,4,60,20], fill=color)
        d.line([52,20,48,55], fill=color, width=6)
        # Opposite legs
        d.line([48,55,58,78], fill=color, width=W)
        d.line([58,78,46,105], fill=color, width=W)
        d.line([48,55,38,72], fill=color, width=W)
        d.line([38,72,52,90], fill=color, width=W)
        # Opposite arms
        d.line([48,30,62,45], fill=color, width=4)
        d.line([62,45,70,55], fill=color, width=4)
        d.line([48,30,33,40], fill=color, width=4)
        d.line([33,40,26,52], fill=color, width=4)
    elif action == "jump":
        # The "swallow" leap — arms and legs spread wide
        d.ellipse([48,2,66,18], fill=color)
        d.line([57,18,54,45], fill=color, width=6)
        # Legs spread (back flip tuck)
        d.line([54,45,34,60], fill=color, width=W)
        d.line([34,60,22,48], fill=color, width=W)
        d.line([54,45,74,62], fill=color, width=W)
        d.line([74,62,82,50], fill=color, width=W)
        # Arms raised up like in screenshot
        d.line([54,28,34,14], fill=color, width=4)
        d.line([34,14,26,6], fill=color, width=4)
        d.line([54,28,74,14], fill=color, width=4)
        d.line([74,14,82,6], fill=color, width=4)
    elif action == "slide":
        # Horizontal slide position
        d.ellipse([62,68,78,84], fill=color)  # head low/back
        d.line([40,76,72,76], fill=color, width=6)  # body horizontal
        d.line([40,76,16,88], fill=color, width=W)
        d.line([16,88,8,80], fill=color, width=W)
        d.line([72,76,90,88], fill=color, width=W)
        d.line([90,88,100,80], fill=color, width=W)
        d.line([40,76,60,65], fill=color, width=4)
        d.line([72,76,86,68], fill=color, width=4)
    elif action == "fall":
        # Arms out, legs bent
        d.ellipse([46,5,62,21], fill=color)
        d.line([54,21,50,52], fill=color, width=6)
        d.line([50,52,35,68], fill=color, width=W)
        d.line([35,68,42,88], fill=color, width=W)
        d.line([50,52,65,70], fill=color, width=W)
        d.line([65,70,60,92], fill=color, width=W)
        d.line([50,32,28,40], fill=color, width=4)
        d.line([28,40,20,52], fill=color, width=4)
        d.line([50,32,72,40], fill=color, width=4)
        d.line([72,40,80,52], fill=color, width=4)
    return img

def make_sheet(path, color):
    frames = ["run1","run2","jump","fall","slide"]
    sheet = Image.new('RGBA', (500, 120), (0,0,0,0))
    for i, f in enumerate(frames):
        sheet.paste(draw_stickman_frame(f, color), (i*100, 0))
    sheet.save(path)

make_sheet(os.path.join(assets_dir, "player_sheet.png"), (0,0,0,255))
make_sheet(os.path.join(assets_dir, "chaser_sheet.png"), (80,0,0,255))
print("Sprite sheets generated")

# 10. Audio
def generate_wav(path, freq_start, freq_end, duration, volume=0.5, sample_rate=44100):
    n = int(duration * sample_rate)
    with wave.open(path, 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sample_rate)
        for i in range(n):
            t = i / sample_rate
            freq = freq_start + (freq_end - freq_start) * (i / n)
            env = 1.0 - (i / n)
            val = int(32767 * volume * env * math.sin(2*math.pi*freq*t))
            w.writeframes(struct.pack('h', val))

generate_wav(os.path.join(assets_dir, "jump.wav"), 250, 700, 0.22)
generate_wav(os.path.join(assets_dir, "coin.wav"), 900, 1400, 0.10, 0.3)
generate_wav(os.path.join(assets_dir, "hit.wav"),  150,  60, 0.30, 0.6)
print("Audio generated")

# -------------------------------------------------------
# SCRIPTS — ported directly from C++ physics constants
# -------------------------------------------------------
SCRIPTS = {
"Player.gd": """extends CharacterBody2D

# Physics constants ported from C++ source
const GRAVITY     = 600.0      # 0.65 px/frame^2 at 60fps -> ~600 px/s^2
const JUMP_POWER  = -630.0     # -10.5 px/frame at 60fps -> ~630 px/s
const RUN_SPEED   = 264.0      # 4.4 px/frame * 60
const FOOT_OFFSET = 40.0

# Animation frame columns in sprite sheet (500x120, 5 frames of 100px each)
const FRAME_RUN1  = 0
const FRAME_RUN2  = 1
const FRAME_JUMP  = 2
const FRAME_FALL  = 3
const FRAME_SLIDE = 4

var state = "run"
var stun_timer = 0.0
var trail = []          # Ghost trail for chaser
var anim_tick = 0

@onready var anim        = $Sprite2D
@onready var col_normal  = $ColNormal
@onready var col_slide   = $ColSlide
@onready var dust        = $DustParticles
@onready var sfx_jump    = $SfxJump
@onready var sfx_hit     = $SfxHit

func _physics_process(delta):
    # Gravity
    if not is_on_floor():
        velocity.y += GRAVITY * delta

    # State machine
    if state == "stun":
        stun_timer -= delta
        velocity.x = RUN_SPEED * 0.3
        if stun_timer <= 0.0:
            state = "run"
    else:
        velocity.x = RUN_SPEED

        # Slide
        if Input.is_action_pressed("slide") and is_on_floor():
            if state != "slide":
                state = "slide"
                col_normal.disabled = true
                col_slide.disabled  = false
                dust.emitting = true
        else:
            if state == "slide":
                state = "run"
                col_normal.disabled = false
                col_slide.disabled  = true
                dust.emitting = false

        # Jump
        if Input.is_action_just_pressed("jump") and is_on_floor() and state != "slide":
            velocity.y = JUMP_POWER
            sfx_jump.play()

        # Derive state from physics
        if not is_on_floor():
            state = "jump" if velocity.y < 0 else "fall"
        elif state not in ["slide"]:
            state = "run"

    move_and_slide()

    # Update animation frame
    anim_tick += 1
    var frame = FRAME_RUN1
    match state:
        "run":
            frame = FRAME_RUN1 if (anim_tick / 8) % 2 == 0 else FRAME_RUN2
        "jump":
            frame = FRAME_JUMP
        "fall":
            frame = FRAME_FALL
        "slide":
            frame = FRAME_SLIDE
        "stun":
            frame = FRAME_RUN1 if (anim_tick / 4) % 2 == 0 else FRAME_FALL

    anim.region_rect = Rect2(frame * 100, 0, 100, 120)

    # Record trail for chaser
    trail.append({"pos": global_position, "state": state, "vel_y": velocity.y})
    if trail.size() > 360:
        trail.pop_front()

func stun():
    if state == "stun":
        return
    state = "stun"
    stun_timer = 1.2
    sfx_hit.play()
    modulate = Color(1, 0.4, 0.4)
    await get_tree().create_timer(1.2).timeout
    modulate = Color(1, 1, 1)
""",

"Chaser.gd": """extends Node2D

@export var player_path: NodePath

var player      = null
var anim        = null
var delay_frames = 90    # ~1.5s behind at 60fps
var game_over    = false
var anim_tick    = 0

func _ready():
    player = get_node_or_null(player_path)
    anim   = get_node_or_null("Sprite2D")
    if not player:
        set_physics_process(false)

func _physics_process(delta):
    if game_over or not player:
        return
    if player.trail.size() == 0:
        return

    # Reduce delay when player is stunned (chaser speeds up)
    if player.state == "stun":
        delay_frames = max(20, delay_frames - 2)
    else:
        delay_frames = min(90, delay_frames + 1)

    var target_idx = max(0, player.trail.size() - delay_frames - 1)
    var data = player.trail[target_idx]
    global_position = data["pos"]

    # Animate
    anim_tick += 1
    var frame = 0
    var p_state = data["state"]
    match p_state:
        "run":
            frame = 0 if (anim_tick / 8) % 2 == 0 else 1
        "jump":
            frame = 2
        "fall":
            frame = 3
        "slide":
            frame = 4
        _:
            frame = 0

    if anim:
        anim.region_rect = Rect2(frame * 100, 0, 100, 120)

    # Catch condition
    if global_position.distance_to(player.global_position) < 55:
        game_over = true
        set_physics_process(false)
        if player.has_method("stun"):
            player.stun()
        await get_tree().create_timer(1.5).timeout
        get_tree().reload_current_scene()
""",

"LevelManager.gd": """extends Node2D

# Procedural city constants (from C++ source)
const PLATFORM_SPACING   = 245.0
const BACKGROUND_SPACING = 185.0

# Rooftop height pattern (from C++ foregroundTopForIndex pattern1)
const ROOF_PATTERN = [295,288,280,272,264,256,280,272,264,256,248,270,262,254,276,284]

@onready var player     = $Player
@onready var hud_score  = $CanvasLayer/HUD/Score
@onready var hud_danger = $CanvasLayer/HUD/Danger
@onready var sfx_coin   = $SfxCoin

var score     = 0
var distance  = 0.0
var chunk_idx = 0   # next platform index to spawn
var despawn_idx = -3  # platforms behind this are removed

var ground_tex   = preload("res://assets/ground.png")
var tank_tex     = preload("res://assets/obs_tall.png")
var crate_tex    = preload("res://assets/obs_crate.png")
var fence_tex    = preload("res://assets/obs_low.png")
var coin_tex     = preload("res://assets/coin.png")

# Obstacle pattern (from C++ obstacleKindForIndex pattern1)
# 0=none, 1=tank, 2=crate, 3=fence
const OBS_PATTERN = [0, 3, 0, 1, 0, 2, 0, 1]

# Spawned platform nodes for cleanup
var platform_nodes = {}

func _ready():
    # Pre-spawn first 5 platforms
    for i in range(-1, 5):
        spawn_platform(i)
    chunk_idx = 5

func _process(_delta):
    if not player:
        return

    distance = player.global_position.x / 100.0
    score = int(distance) + score
    hud_score.text = "Distance: %dm | Score: %d" % [int(distance), score]

    # Danger warning
    var chaser = get_node_or_null("Chaser")
    if chaser:
        var dist_to_chaser = player.global_position.x - chaser.global_position.x
        hud_danger.visible = dist_to_chaser < 300
        hud_danger.modulate.a = 1.0 if int(Time.get_ticks_msec() / 300) % 2 == 0 else 0.4

    # Spawn ahead
    while chunk_idx * PLATFORM_SPACING < player.global_position.x + 1600:
        spawn_platform(chunk_idx)
        chunk_idx += 1

    # Despawn behind
    while despawn_idx * PLATFORM_SPACING < player.global_position.x - 600:
        if platform_nodes.has(despawn_idx):
            platform_nodes[despawn_idx].queue_free()
            platform_nodes.erase(despawn_idx)
        despawn_idx += 1

func get_roof_y(index):
    return ROOF_PATTERN[posmod(index, 16)]

func get_obs_kind(index):
    if index < 1:
        return 0
    return OBS_PATTERN[posmod(index, 8)]

func spawn_platform(index):
    if platform_nodes.has(index):
        return

    var root = Node2D.new()
    root.name = "Platform_%d" % index
    add_child(root)
    platform_nodes[index] = root

    var roof_y = get_roof_y(index)
    var left_x = index * PLATFORM_SPACING

    # Ground body
    var body = StaticBody2D.new()
    body.position = Vector2(left_x + PLATFORM_SPACING * 0.5, roof_y)
    root.add_child(body)

    var spr = Sprite2D.new()
    spr.texture = ground_tex
    spr.scale = Vector2(PLATFORM_SPACING / 500.0, 1.0)
    spr.position = Vector2(0, 0)
    body.add_child(spr)

    var col = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(PLATFORM_SPACING, 120)
    col.shape = shape
    col.position = Vector2(0, 60)
    body.add_child(col)

    # Obstacle
    var obs_kind = get_obs_kind(index)
    if obs_kind != 0:
        var obs_tex = null
        var obs_w = 0.0
        var obs_h = 0.0
        match obs_kind:
            1: obs_tex = tank_tex;  obs_w = 44; obs_h = 62
            2: obs_tex = crate_tex; obs_w = 32; obs_h = 32
            3: obs_tex = fence_tex; obs_w = 62; obs_h = 22

        var obs_area = Area2D.new()
        obs_area.position = Vector2(
            left_x + PLATFORM_SPACING * 0.60,
            roof_y - obs_h * 0.5
        )
        root.add_child(obs_area)

        var o_spr = Sprite2D.new()
        o_spr.texture = obs_tex
        obs_area.add_child(o_spr)

        var o_col = CollisionShape2D.new()
        var o_shape = RectangleShape2D.new()
        o_shape.size = Vector2(obs_w, obs_h)
        o_col.shape = o_shape
        obs_area.add_child(o_col)

        obs_area.body_entered.connect(_on_obstacle_hit.bind(obs_area))
        obs_area.body_exited.connect(_on_obstacle_clear.bind(obs_area))

    # Coins (3 per platform, floating above)
    for i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(
            left_x + PLATFORM_SPACING * (0.2 + i * 0.25),
            roof_y - 50 - randf_range(0, 40)
        )
        root.add_child(coin)

        var c_spr = Sprite2D.new()
        c_spr.texture = coin_tex
        coin.add_child(c_spr)

        var c_col = CollisionShape2D.new()
        var c_shape = CircleShape2D.new()
        c_shape.radius = 12
        c_col.shape = c_shape
        coin.add_child(c_col)
        coin.body_entered.connect(_on_coin_hit.bind(coin))

func show_popup(txt, pos):
    var lbl = Label.new()
    lbl.text = txt
    lbl.global_position = pos + Vector2(-20, -40)
    lbl.add_theme_color_override("font_color", Color(1,1,0))
    lbl.add_theme_font_size_override("font_size", 22)
    add_child(lbl)
    var tw = create_tween()
    tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 80, 0.9)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.9)
    tw.tween_callback(lbl.queue_free)

func _on_obstacle_hit(body, _obs):
    if body.name == "Player":
        body.stun()

func _on_obstacle_clear(body, _obs):
    if body.name == "Player" and body.state != "stun":
        score += 50
        show_popup("Swallow\\n+50", body.global_position)

func _on_coin_hit(body, coin):
    if body.name == "Player":
        score += 10
        sfx_coin.play()
        show_popup("+10", coin.global_position)
        coin.queue_free()
"""
}

for name, content in SCRIPTS.items():
    with open(os.path.join(scripts_dir, name), "w") as f:
        f.write(content)
print("Scripts written")

# -------------------------------------------------------
# SCENES
# -------------------------------------------------------
player_tscn = """[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://scripts/Player.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/player_sheet.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/particle.png" id="3"]
[ext_resource type="AudioStream" path="res://assets/jump.wav" id="4"]
[ext_resource type="AudioStream" path="res://assets/hit.wav" id="5"]

[sub_resource type="RectangleShape2D" id="norm"]
size = Vector2(28, 70)
[sub_resource type="RectangleShape2D" id="slide"]
size = Vector2(75, 35)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")
region_enabled = true
region_rect = Rect2(0, 0, 100, 120)
offset = Vector2(0, -20)

[node name="ColNormal" type="CollisionShape2D" parent="."]
position = Vector2(0, -5)
shape = SubResource("norm")

[node name="ColSlide" type="CollisionShape2D" parent="."]
position = Vector2(0, 10)
shape = SubResource("slide")
disabled = true

[node name="DustParticles" type="CPUParticles2D" parent="."]
position = Vector2(-10, 35)
emitting = false
amount = 12
texture = ExtResource("3")
gravity = Vector2(-150, -80)
initial_velocity_min = 40.0
initial_velocity_max = 90.0
scale_amount_min = 0.3
scale_amount_max = 1.5
color = Color(0.7, 0.7, 0.7, 0.5)

[node name="SfxJump" type="AudioStreamPlayer" parent="."]
stream = ExtResource("4")
volume_db = -6.0
[node name="SfxHit" type="AudioStreamPlayer" parent="."]
stream = ExtResource("5")
volume_db = -3.0
"""

chaser_tscn = """[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/Chaser.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/chaser_sheet.png" id="2"]

[node name="Chaser" type="Node2D"]
script = ExtResource("1")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")
region_enabled = true
region_rect = Rect2(0, 0, 100, 120)
offset = Vector2(0, -20)
"""

main_tscn = """[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://scripts/LevelManager.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/sky.png" id="2"]
[ext_resource type="Texture2D" path="res://assets/city_far.png" id="3"]
[ext_resource type="Texture2D" path="res://assets/city_mid.png" id="4"]
[ext_resource type="PackedScene" path="res://scenes/Player.tscn" id="5"]
[ext_resource type="PackedScene" path="res://scenes/Chaser.tscn" id="6"]
[ext_resource type="AudioStream" path="res://assets/coin.wav" id="7"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="ParallaxBackground" type="ParallaxBackground" parent="."]

[node name="SkyLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0, 0)
[node name="Sprite2D" type="Sprite2D" parent="ParallaxBackground/SkyLayer"]
texture = ExtResource("2")
centered = false
scale = Vector2(1, 1)

[node name="CityFarLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.08, 0)
motion_mirroring = Vector2(2560, 0)
[node name="Sprite2D" type="Sprite2D" parent="ParallaxBackground/CityFarLayer"]
texture = ExtResource("3")
centered = false

[node name="CityMidLayer" type="ParallaxLayer" parent="ParallaxBackground"]
motion_scale = Vector2(0.22, 0)
motion_mirroring = Vector2(2560, 0)
[node name="Sprite2D" type="Sprite2D" parent="ParallaxBackground/CityMidLayer"]
texture = ExtResource("4")
centered = false

[node name="Player" parent="." instance=ExtResource("5")]
position = Vector2(300, 200)

[node name="Camera2D" type="Camera2D" parent="Player"]
position = Vector2(220, -80)
limit_bottom = 800
position_smoothing_enabled = true
position_smoothing_speed = 7.0

[node name="Chaser" parent="." instance=ExtResource("6")]
position = Vector2(50, 200)
player_path = NodePath("../Player")

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
offset_top = 16.0
offset_right = 700.0
offset_bottom = 56.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2
theme_override_font_sizes/font_size = 28
text = "Distance: 0m | Score: 0"
[node name="Danger" type="Label" parent="CanvasLayer/HUD"]
visible = false
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -280.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = 56.0
theme_override_colors/font_color = Color(1, 0.2, 0.2, 1)
theme_override_colors/font_shadow_color = Color(0, 0, 0, 1)
theme_override_constants/shadow_offset_x = 2
theme_override_constants/shadow_offset_y = 2
theme_override_font_sizes/font_size = 28
text = "!! CHASER CLOSE !!"
"""

project_godot = """
; Engine configuration file.
[application]
config/name="Vector Runner"
run/main_scene="res://scenes/Main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="gl_compatibility"

[input]
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null),
Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
slide={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null),
Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":0,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
"""

with open(os.path.join(scenes_dir, "Player.tscn"), "w") as f: f.write(player_tscn)
with open(os.path.join(scenes_dir, "Chaser.tscn"), "w") as f: f.write(chaser_tscn)
with open(os.path.join(scenes_dir, "Main.tscn"),  "w") as f: f.write(main_tscn)
with open(os.path.join(base_dir, "project.godot"), "w") as f: f.write(project_godot.strip())
print("Scenes and project.godot written")
print("\nDONE! Reload Godot, open Main.tscn, and press Play!")
