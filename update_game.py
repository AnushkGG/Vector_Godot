import os
from PIL import Image, ImageDraw

base_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
assets = os.path.join(base_dir, "assets")
scripts = os.path.join(base_dir, "scripts")

# 1. GENERATE MUSCULAR "SEXY" SPRITES
def draw_muscle_pose(pose, color):
    img = Image.new('RGBA', (100, 100), (0,0,0,0))
    d = ImageDraw.Draw(img)
    
    def limb(x1, y1, x2, y2, w):
        d.line([x1, y1, x2, y2], fill=color, width=w)
        d.ellipse([x1-w//2, y1-w//2, x1+w//2, y1+w//2], fill=color)
        d.ellipse([x2-w//2, y2-w//2, x2+w//2, y2+w//2], fill=color)

    if pose == 'run1':
        d.ellipse([46, 12, 60, 26], fill=color) # Head
        d.polygon([(52, 25), (66, 32), (56, 52), (40, 48), (42, 28)], fill=color) # Torso
        limb(50, 46, 68, 62, 14) # Front thigh
        limb(68, 62, 55, 88, 10) # Front calf
        limb(45, 46, 32, 60, 14) # Back thigh
        limb(32, 60, 20, 82, 10) # Back calf
        limb(55, 30, 42, 42, 11) # Front bicep
        limb(42, 42, 32, 36, 9)  # Front forearm
        limb(60, 30, 78, 42, 11) # Back bicep
        limb(78, 42, 88, 30, 9)  # Back forearm
    elif pose == 'run2':
        d.ellipse([46, 12, 60, 26], fill=color)
        d.polygon([(52, 25), (66, 32), (56, 52), (40, 48), (42, 28)], fill=color)
        limb(45, 46, 45, 75, 14) 
        limb(45, 75, 35, 90, 10)
        limb(50, 46, 68, 55, 14) 
        limb(68, 55, 80, 70, 10)
        limb(55, 30, 72, 42, 11) 
        limb(72, 42, 68, 58, 9)  
        limb(60, 30, 50, 48, 11) 
        limb(50, 48, 62, 58, 9)  
    elif pose == 'jump':
        d.ellipse([42, 5, 56, 19], fill=color)
        d.polygon([(48, 18), (62, 20), (58, 45), (42, 43), (40, 20)], fill=color)
        limb(50, 42, 70, 35, 14)
        limb(70, 35, 60, 55, 10)
        limb(45, 40, 25, 45, 14)
        limb(25, 45, 40, 60, 10)
        limb(55, 22, 70, 10, 11)
        limb(70, 10, 85, 15, 9)
        limb(45, 22, 30, 10, 11)
        limb(30, 10, 15, 15, 9)
    elif pose == 'slide':
        d.ellipse([65, 68, 79, 82], fill=color)
        d.polygon([(68, 72), (75, 85), (40, 90), (35, 78), (55, 68)], fill=color)
        limb(40, 80, 15, 92, 14)
        limb(15, 92, 5, 90, 10)
        limb(35, 85, 20, 75, 14)
        limb(20, 75, 5, 80, 10)
        limb(62, 75, 52, 95, 11)
        limb(58, 72, 72, 95, 11)
    return img

def make_sheet(path, color):
    sheet = Image.new('RGBA', (400, 100), (0,0,0,0))
    sheet.paste(draw_muscle_pose('run1', color), (0, 0))
    sheet.paste(draw_muscle_pose('run2', color), (100, 0))
    sheet.paste(draw_muscle_pose('jump', color), (200, 0))
    sheet.paste(draw_muscle_pose('slide', color), (300, 0))
    sheet.save(path)

make_sheet(os.path.join(assets, "player_sheet.png"), (0,0,0,255))
make_sheet(os.path.join(assets, "chaser_sheet.png"), (180,10,10,255))
print("Muscular sprites generated")

# 2. GENERATE SMALLER POWER POLE
w, h = 40, 60
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
d.rectangle([18, 0, 22, 60], fill='black')
d.rectangle([5, 8, 35, 12], fill='black')
for ix in [8, 20, 32]:
    d.ellipse([ix-3, 5, ix+3, 10], fill='black')
d.line([8, 8, 0, 20], fill='black', width=1)
d.line([32, 8, 40, 20], fill='black', width=1)
d.line([20, 10, 0, 25], fill='black', width=1)
d.line([20, 10, 40, 25], fill='black', width=1)
img.save(os.path.join(assets, "obs_pole.png"))
print("Smaller pole generated")

# 3. REWRITE CHASER.GD TO STAY CLOSE TO PLAYER (DELAY = 35)
chaser_gd = """extends Node2D

@export var player_path: NodePath

var player = null
var anim = null
var delay_frames = 35
var current_catch_up = 0.0
var game_over = false

func _ready():
    player = get_node_or_null(player_path)
    anim = get_node_or_null("Sprite2D")
    if not player:
        set_physics_process(false)

func _physics_process(delta):
    if game_over or not player:
        return
    if player.trail.size() == 0:
        return

    # Speed up when player stunned
    if player.state == "stun":
        delay_frames = max(5, delay_frames - 2)
    else:
        if delay_frames < 35:
            current_catch_up += delta
            if current_catch_up > 0.08:
                delay_frames += 1
                current_catch_up = 0.0

    var target_idx = player.trail.size() - delay_frames - 1
    if target_idx < 0:
        target_idx = 0

    var data = player.trail[target_idx]
    global_position = data["pos"]
    var p_state = data["state"]

    if anim:
        var rect_x = 0
        if p_state == "run" or p_state == "stun":
            rect_x = (Engine.get_frames_drawn() / 10 % 2) * 100
        elif p_state == "jump" or p_state == "fall":
            rect_x = 200
        elif p_state == "slide":
            rect_x = 300
        anim.region_rect = Rect2(rect_x, 0, 100, 100)

    # Catch player
    if global_position.distance_to(player.global_position) < 50:
        game_over = true
        set_physics_process(false)
        if player.has_method("set_physics_process"):
            player.set_physics_process(false)
        await get_tree().create_timer(1.5).timeout
        get_tree().reload_current_scene()
"""

with open(os.path.join(scripts, "Chaser.gd"), "w", encoding="utf-8") as f:
    f.write(chaser_gd)
print("Chaser.gd updated (UTF-8)")
