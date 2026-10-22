import os, re

base    = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector"
scripts = os.path.join(base, "scripts")
scenes  = os.path.join(base, "scenes")

# ═══════════════════════════════════════════════════════════
# 1.  NEW: scripts/UI.gd  — builds all overlay UI in code
#     process_mode = ALWAYS so buttons work while tree paused
# ═══════════════════════════════════════════════════════════
open(os.path.join(scripts, "UI.gd"), "w", encoding="utf-8").write("""extends CanvasLayer

signal start_pressed
signal restart_pressed

var menu_panel: Panel
var gameover_panel: Panel
var go_score_lbl: Label

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_menu()
    _build_gameover()
    show_menu()

# ── helpers ────────────────────────────────────────────────
func _styled_panel(w: float, h: float) -> Panel:
    var p := Panel.new()
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.custom_minimum_size = Vector2(w, h)
    p.offset_left   = -w * 0.5
    p.offset_top    = -h * 0.5
    p.offset_right  =  w * 0.5
    p.offset_bottom =  h * 0.5
    var sb := StyleBoxFlat.new()
    sb.bg_color            = Color(0.05, 0.05, 0.1, 0.88)
    sb.border_color        = Color(1.0, 0.55, 0.0, 1.0)
    sb.border_width_left   = 3
    sb.border_width_right  = 3
    sb.border_width_top    = 3
    sb.border_width_bottom = 3
    sb.corner_radius_top_left     = 12
    sb.corner_radius_top_right    = 12
    sb.corner_radius_bottom_left  = 12
    sb.corner_radius_bottom_right = 12
    p.add_theme_stylebox_override("panel", sb)
    return p

func _styled_btn(text: String, w: float) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, 52)
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0))
    b.add_theme_color_override("font_hover_color",   Color(1.0, 0.75, 0.1))
    b.add_theme_color_override("font_pressed_color", Color(0.8, 0.4, 0.0))
    var sbn := StyleBoxFlat.new()
    sbn.bg_color = Color(0.9, 0.45, 0.0, 1.0)
    sbn.corner_radius_top_left     = 8
    sbn.corner_radius_top_right    = 8
    sbn.corner_radius_bottom_left  = 8
    sbn.corner_radius_bottom_right = 8
    var sbh := sbn.duplicate() as StyleBoxFlat
    sbh.bg_color = Color(1.0, 0.6, 0.05, 1.0)
    var sbp := sbn.duplicate() as StyleBoxFlat
    sbp.bg_color = Color(0.65, 0.3, 0.0, 1.0)
    b.add_theme_stylebox_override("normal",  sbn)
    b.add_theme_stylebox_override("hover",   sbh)
    b.add_theme_stylebox_override("pressed", sbp)
    return b

func _lbl(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l

# ── Menu panel ─────────────────────────────────────────────
func _build_menu() -> void:
    menu_panel = _styled_panel(420, 280)
    add_child(menu_panel)

    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.offset_left = 30; vbox.offset_right  = -30
    vbox.offset_top  = 30; vbox.offset_bottom = -30
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 18)
    menu_panel.add_child(vbox)

    vbox.add_child(_lbl("SHADOW RUNNER", 36, Color(1.0, 0.6, 0.0)))
    vbox.add_child(_lbl("Jump: W / Up Arrow\\nSlide: S / Down Arrow", 16, Color(0.8, 0.8, 0.8)))

    var sep := Control.new(); sep.custom_minimum_size = Vector2(0, 10)
    vbox.add_child(sep)

    var btn := _styled_btn("START GAME", 260)
    btn.process_mode = Node.PROCESS_MODE_ALWAYS
    btn.pressed.connect(_on_start_pressed)
    vbox.add_child(btn)

# ── Game-Over panel ────────────────────────────────────────
func _build_gameover() -> void:
    gameover_panel = _styled_panel(420, 300)
    gameover_panel.visible = false
    add_child(gameover_panel)

    var vbox := VBoxContainer.new()
    vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    vbox.offset_left = 30; vbox.offset_right  = -30
    vbox.offset_top  = 30; vbox.offset_bottom = -30
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 16)
    gameover_panel.add_child(vbox)

    vbox.add_child(_lbl("GAME OVER", 40, Color(1.0, 0.25, 0.2)))

    go_score_lbl = _lbl("", 20, Color(0.9, 0.9, 0.9))
    vbox.add_child(go_score_lbl)

    var sep := Control.new(); sep.custom_minimum_size = Vector2(0, 10)
    vbox.add_child(sep)

    var btn := _styled_btn("RESTART", 220)
    btn.process_mode = Node.PROCESS_MODE_ALWAYS
    btn.pressed.connect(_on_restart_pressed)
    vbox.add_child(btn)

# ── Public API ─────────────────────────────────────────────
func show_menu() -> void:
    menu_panel.visible    = true
    gameover_panel.visible = false

func show_gameover(score: int, dist: int) -> void:
    go_score_lbl.text      = "Distance: %dm    Score: %d" % [dist, score]
    menu_panel.visible     = false
    gameover_panel.visible = true

func hide_all() -> void:
    menu_panel.visible    = false
    gameover_panel.visible = false

func _on_start_pressed()   -> void: emit_signal("start_pressed")
func _on_restart_pressed() -> void: emit_signal("restart_pressed")
""")
print("UI.gd written")

# ═══════════════════════════════════════════════════════════
# 2.  NEW: scenes/UI.tscn  — minimal wrapper for UI.gd
# ═══════════════════════════════════════════════════════════
open(os.path.join(scenes, "UI.tscn"), "w", encoding="utf-8").write("""[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/UI.gd" id="1"]

[node name="UI" type="CanvasLayer"]
layer = 10
script = ExtResource("1")
""")
print("UI.tscn written")

# ═══════════════════════════════════════════════════════════
# 3.  PATCH Player.gd
#     — add  signal died
#     — replace reload_current_scene() with emit_signal("died")
# ═══════════════════════════════════════════════════════════
player_path = os.path.join(scripts, "Player.gd")
src = open(player_path, encoding="utf-8").read()

# Add signal after first line (extends CharacterBody2D)
if "signal died" not in src:
    src = src.replace(
        "extends CharacterBody2D",
        "extends CharacterBody2D\n\nsignal died"
    )

# Replace the death reload with emit
src = src.replace(
    "get_tree().reload_current_scene()",
    "died.emit()",
    1   # only the first occurrence (inside _physics_process)
)

open(player_path, "w", encoding="utf-8").write(src)
print("Player.gd patched (signal died)")

# ═══════════════════════════════════════════════════════════
# 4.  PATCH LevelManager.gd
#     — add UI node reference + game-state management in _ready / _process
# ═══════════════════════════════════════════════════════════
lm_path = os.path.join(scripts, "LevelManager.gd")
src = open(lm_path, encoding="utf-8").read()

# Add UI onready and state var after existing onready lines
OLD_ONREADY = """@onready var sfx_coin = $SfxCoin
var chunk_x = 2000.0
var score = 0
var distance = 0.0"""

NEW_ONREADY = """@onready var sfx_coin  = $SfxCoin
@onready var ui        = $UI

enum GameState { MENU, PLAYING, GAME_OVER }
var game_state: GameState = GameState.MENU

var chunk_x  = 2000.0
var score    = 0
var distance = 0.0"""

src = src.replace(OLD_ONREADY, NEW_ONREADY)

# Add _ready() function before _process
if "func _ready()" not in src:
    src = src.replace(
        "func _process(_delta):",
        """func _ready() -> void:
    get_tree().paused = true
    ui.start_pressed.connect(_on_start_pressed)
    ui.restart_pressed.connect(_on_restart_pressed)
    player.died.connect(_on_player_died)

func _on_start_pressed() -> void:
    game_state = GameState.PLAYING
    get_tree().paused = false
    ui.hide_all()

func _on_player_died() -> void:
    game_state = GameState.GAME_OVER
    get_tree().paused = true
    ui.show_gameover(score, int(distance))

func _on_restart_pressed() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _process(_delta):"""
    )
    # Avoid duplicate func _process
    src = src.replace("func _process(_delta):\nfunc _process(_delta):", "func _process(_delta):")

open(lm_path, "w", encoding="utf-8").write(src)
print("LevelManager.gd patched (game state + UI hooks)")

# ═══════════════════════════════════════════════════════════
# 5.  PATCH Main.tscn — append UI node instance at the end
# ═══════════════════════════════════════════════════════════
main_path = os.path.join(scenes, "Main.tscn")
main_src  = open(main_path, encoding="utf-8").read()

ui_ext = '[ext_resource type="PackedScene" path="res://scenes/UI.tscn" id="ui_scene"]'
ui_node = '\n[node name="UI" parent="." instance=ExtResource("ui_scene")]'

if 'res://scenes/UI.tscn' not in main_src:
    # Insert ext_resource after last existing one
    last_ext = main_src.rfind('[ext_resource')
    end_of_last = main_src.find('\n', last_ext) + 1
    main_src = main_src[:end_of_last] + ui_ext + "\n" + main_src[end_of_last:]
    # Append node at end
    main_src = main_src.rstrip() + ui_node + "\n"

open(main_path, "w", encoding="utf-8").write(main_src)
print("Main.tscn patched (UI node added)")

print("\nDone. Reload All in Godot -> Play")
