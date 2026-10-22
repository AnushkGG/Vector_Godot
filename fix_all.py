import os
from PIL import Image, ImageDraw

base    = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets  = os.path.join(base, "assets")
scripts = os.path.join(base, "scripts")
scenes  = os.path.join(base, "scenes")

# ══════════════════════════════════════════════
# 1. REGENERATE SPRITES - player BLACK, chaser DARK RED
# ══════════════════════════════════════════════
def draw_man(pose, color, img_size=(100,100)):
    img = Image.new('RGBA', img_size, (0,0,0,0))
    d = ImageDraw.Draw(img)

    def limb(ax,ay,bx,by,w):
        d.line([(ax,ay),(bx,by)], fill=color, width=w)
        d.ellipse([ax-w//2,ay-w//2,ax+w//2,ay+w//2], fill=color)
        d.ellipse([bx-w//2,by-w//2,bx+w//2,by+w//2], fill=color)

    if pose == 'run1':
        d.ellipse([44,6,60,22],  fill=color)           # head
        d.polygon([(52,21),(64,28),(57,56),(43,52),(44,26)], fill=color) # torso
        limb(52,21, 50,12, 4)                           # neck
        limb(55,32, 40,46, 9)                           # L arm
        limb(40,46, 30,38, 7)
        limb(57,32, 72,44, 9)                           # R arm
        limb(72,44, 80,36, 7)
        limb(50,53, 36,74, 11)                          # L leg (forward)
        limb(36,74, 46,96, 9)
        limb(55,53, 68,70, 11)                          # R leg (back)
        limb(68,70, 56,88, 9)
    elif pose == 'run2':
        d.ellipse([44,6,60,22],  fill=color)
        d.polygon([(52,21),(64,28),(57,56),(43,52),(44,26)], fill=color)
        limb(52,21, 50,12, 4)
        limb(55,32, 72,44, 9)
        limb(72,44, 80,55, 7)
        limb(57,32, 40,46, 9)
        limb(40,46, 32,38, 7)
        limb(55,53, 66,76, 11)
        limb(66,76, 52,96, 9)
        limb(50,53, 38,72, 11)
        limb(38,72, 48,90, 9)
    elif pose == 'jump':
        d.ellipse([40,2,56,18],  fill=color)
        d.polygon([(48,17),(60,22),(55,50),(41,48),(40,22)], fill=color)
        limb(48,17, 46,9, 4)
        limb(52,28, 70,16, 9)
        limb(70,16, 82,20, 7)
        limb(50,28, 30,18, 9)
        limb(30,18, 18,22, 7)
        limb(53,48, 72,36, 11)
        limb(72,36, 62,56, 9)
        limb(47,48, 28,38, 11)
        limb(28,38, 38,58, 9)
    elif pose == 'slide':
        d.ellipse([62,66,78,82], fill=color)
        d.polygon([(66,76),(74,84),(36,90),(32,80),(52,66)], fill=color)
        limb(36,84, 12,92, 11)
        limb(12,92,  4,85, 9)
        limb(40,86, 22,78, 11)
        limb(22,78,  8,82, 9)
        limb(60,76, 48,96, 9)
        limb(60,76, 76,94, 9)
    return img

def make_sheet(path, color):
    sheet = Image.new('RGBA', (400, 100), (0,0,0,0))
    for i, pose in enumerate(['run1','run2','jump','slide']):
        frame = draw_man(pose, color)
        sheet.paste(frame, (i*100, 0), frame)
    sheet.save(path)
    print(f"  Saved: {os.path.basename(path)}")

make_sheet(os.path.join(assets, "player_sheet.png"), (10, 10, 10, 255))      # BLACK
make_sheet(os.path.join(assets, "chaser_sheet.png"), (160, 20, 20, 255))     # DARK RED

# ══════════════════════════════════════════════
# 2. CAMERA SCRIPT - NO Y lerp, lock to fixed height, only scroll X
# ══════════════════════════════════════════════
camera_gd = """extends Camera2D

# Fixed ground level - camera always shows this Y band
const GROUND_Y    = 560.0
const CAM_OFFSET_X = 280.0
const CAM_OFFSET_Y = -200.0

@export var target_path: NodePath
var target = null

func _ready():
    target = get_node_or_null(target_path)
    position_smoothing_enabled = false
    make_current()

func _physics_process(_delta):
    if not target:
        return
    # X: follow player exactly (no smoothing = no oscillation)
    global_position.x = target.global_position.x + CAM_OFFSET_X
    # Y: fixed to ground level - never bobs
    global_position.y = GROUND_Y + CAM_OFFSET_Y
"""

# ══════════════════════════════════════════════
# 3. LEVEL MANAGER - ALL platforms at SAME fixed Y (no random height!)
# ══════════════════════════════════════════════
level_gd = """# Vector Runner - Level Manager
extends Node2D

@onready var player    = $Player
@onready var hud_score = $CanvasLayer/HUD/Score
@onready var sfx_coin  = $SfxCoin

var chunk_x  = 0.0
var score    = 0
var distance = 0.0
var chunks   = []

const GROUND_Y = 560.0   # fixed - all platforms at same height = smooth camera

var ground_tex = preload("res://assets/ground.png")
var coin_tex   = preload("res://assets/coin.png")

var obs_types = [
    ["res://assets/obs_watertank.png",  50,  80, false],
    ["res://assets/obs_crane.png",     120,  90, false],
    ["res://assets/obs_ladder.png",     30,  90, false],
    ["res://assets/obs_satellite.png",  55,  70, false],
    ["res://assets/obs_vent.png",       70,  45, false],
    ["res://assets/obs_pole.png",       40,  60, false],
    ["res://assets/obs_billboard.png",  80,  70, false],
    ["res://assets/obs_tall.png",       30, 120, false],
    ["res://assets/obs_crate.png",      60,  60, false],
    ["res://assets/obs_arch.png",      160,  50, true],
    ["res://assets/obs_low.png",       200,  30, true],
]

func _ready():
    for i in range(8):
        spawn_chunk(i < 3)   # first 3 are obstacle-free safe zones

func _process(_delta):
    if not player:
        return
    distance = player.global_position.x / 100.0
    hud_score.text = "Distance: %dm  Score: %d" % [int(distance), score]
    if player.global_position.x + 2000 > chunk_x:
        spawn_chunk(false)
    for c in chunks.duplicate():
        if c and is_instance_valid(c) and c.position.x < player.global_position.x - 1500:
            c.queue_free()
            chunks.erase(c)

func spawn_chunk(safe: bool):
    var root = Node2D.new()
    root.position = Vector2(chunk_x, 0)
    add_child(root)
    chunks.append(root)

    var gb = StaticBody2D.new()
    gb.position = Vector2(0, GROUND_Y)
    root.add_child(gb)

    var g_spr = Sprite2D.new()
    g_spr.texture  = ground_tex
    g_spr.position = Vector2(500, 60)
    g_spr.scale    = Vector2(2.0, 1.0)
    gb.add_child(g_spr)

    var g_col = CollisionShape2D.new()
    var g_shape = RectangleShape2D.new()
    g_shape.size   = Vector2(1000, 120)
    g_col.shape    = g_shape
    g_col.position = Vector2(500, 60)
    gb.add_child(g_col)

    if not safe:
        if randf() > 0.25:
            root.add_child(_make_obstacle(randf_range(350, 750)))
        if randf() > 0.6:
            root.add_child(_make_obstacle(randf_range(100, 300)))

    for _i in range(3):
        var coin = Area2D.new()
        coin.position = Vector2(randf_range(120, 900), GROUND_Y - randf_range(60, 160))
        var c_spr   = Sprite2D.new()
        c_spr.texture = coin_tex
        var c_col   = CollisionShape2D.new()
        var c_shape = CircleShape2D.new()
        c_shape.radius = 16
        c_col.shape  = c_shape
        coin.add_child(c_spr)
        coin.add_child(c_col)
        coin.body_entered.connect(_on_coin_hit.bind(coin))
        root.add_child(coin)

    chunk_x += 1000

func _make_obstacle(offset_x: float) -> Node2D:
    var info     = obs_types[randi() % obs_types.size()]
    var tex_path = info[0]
    var obs_w    = float(info[1]) * 1.4
    var obs_h    = float(info[2]) * 1.4
    var is_low   = bool(info[3])

    var obs
    if is_low:
        obs = Area2D.new()
        obs.body_entered.connect(_on_obstacle_hit.bind(obs))
        obs.body_exited.connect(_on_obstacle_clear.bind(obs))
    else:
        obs = StaticBody2D.new()
        var sa = Area2D.new()
        sa.position = Vector2(0, -obs_h - 80)
        var sc = CollisionShape2D.new()
        var ss = RectangleShape2D.new()
        ss.size    = Vector2(obs_w, 160)
        sc.shape   = ss
        sa.add_child(sc)
        sa.body_exited.connect(_on_obstacle_clear.bind(sa))
        obs.add_child(sa)

    obs.position = Vector2(offset_x, GROUND_Y)

    var o_spr = Sprite2D.new()
    o_spr.texture  = load(tex_path)
    o_spr.scale    = Vector2(1.4, 1.4)
    o_spr.position = Vector2(0, -obs_h * 0.5)
    obs.add_child(o_spr)

    var o_col = CollisionShape2D.new()
    var o_shape = RectangleShape2D.new()
    o_shape.size   = Vector2(obs_w, obs_h)
    o_col.shape    = o_shape
    o_col.position = Vector2(0, -obs_h * 0.5)
    obs.add_child(o_col)
    return obs

func show_popup(txt, pos):
    var lbl = Label.new()
    lbl.text = txt
    lbl.global_position = pos + Vector2(-20, -50)
    lbl.add_theme_color_override("font_color", Color(1,1,0))
    lbl.add_theme_font_size_override("font_size", 24)
    add_child(lbl)
    var tw = create_tween()
    tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 100, 1.0)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
    tw.tween_callback(lbl.queue_free)

func _on_obstacle_hit(body, _obs):
    if body.name == "Player":
        body.stun()

func _on_obstacle_clear(body, _obs):
    if body.name == "Player" and body.state != "stun":
        score += 50
        show_popup("+50", body.global_position)

func _on_coin_hit(body, coin_node):
    if body.name == "Player":
        score += 10
        sfx_coin.play()
        show_popup("+10", coin_node.global_position)
        coin_node.queue_free()
"""

with open(os.path.join(scripts, "Camera.gd"),       "w", encoding="utf-8") as f: f.write(camera_gd)
with open(os.path.join(scripts, "LevelManager.gd"), "w", encoding="utf-8") as f: f.write(level_gd)
print("Scripts written")
print("Done! Reload in Godot and press Play.")
