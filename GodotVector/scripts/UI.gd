extends CanvasLayer

signal start_pressed
signal restart_pressed
signal next_level_pressed
signal play_again_pressed

var menu_panel        : Panel
var gameover_panel    : Panel
var level_complete_panel : Panel
var you_win_panel     : Panel
var go_score_lbl      : Label
var fast_btn          : Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_fast_button()
    _build_menu()
    _build_gameover()
    _build_level_complete()
    _build_you_win()
    show_menu()


# ── shared helpers ──────────────────────────────────────────
func _styled_panel(w: float, h: float) -> Panel:
    var p := Panel.new()
    p.set_anchors_preset(Control.PRESET_CENTER)
    p.custom_minimum_size = Vector2(w, h)
    p.offset_left   = -w * 0.5
    p.offset_top    = -h * 0.5
    p.offset_right  =  w * 0.5
    p.offset_bottom =  h * 0.5
    var sb := StyleBoxFlat.new()
    sb.bg_color            = Color(0.02, 0.02, 0.10, 0.94)  # deep midnight panel
    sb.border_color        = Color(0.00, 0.92, 0.98, 1.0)  # neon cyan border
    sb.border_width_left   = 3
    sb.border_width_right  = 3
    sb.border_width_top    = 3
    sb.border_width_bottom = 3
    sb.corner_radius_top_left     = 14
    sb.corner_radius_top_right    = 14
    sb.corner_radius_bottom_left  = 14
    sb.corner_radius_bottom_right = 14
    p.add_theme_stylebox_override("panel", sb)
    return p

func _styled_btn(text: String, w: float, col: Color = Color(0.30, 0.05, 0.80)) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, 52)
    b.process_mode = Node.PROCESS_MODE_ALWAYS
    b.add_theme_font_size_override("font_size", 22)
    b.add_theme_color_override("font_color",         Color(1, 1, 1))
    b.add_theme_color_override("font_hover_color",   Color(1, 0.85, 0.2))
    b.add_theme_color_override("font_pressed_color", Color(0.7, 0.3, 0.0))
    var sbn := StyleBoxFlat.new()
    sbn.bg_color = col
    sbn.corner_radius_top_left     = 8
    sbn.corner_radius_top_right    = 8
    sbn.corner_radius_bottom_left  = 8
    sbn.corner_radius_bottom_right = 8
    var sbh := sbn.duplicate() as StyleBoxFlat
    sbh.bg_color = col.lightened(0.2)
    var sbp := sbn.duplicate() as StyleBoxFlat
    sbp.bg_color = col.darkened(0.25)
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

func _vbox(panel: Panel, pad: float = 30.0) -> VBoxContainer:
    var v := VBoxContainer.new()
    v.set_anchors_preset(Control.PRESET_FULL_RECT)
    v.offset_left = pad; v.offset_right  = -pad
    v.offset_top  = pad; v.offset_bottom = -pad
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 16)
    panel.add_child(v)
    return v

func _spacer(h: float = 8.0) -> Control:
    var c := Control.new()
    c.custom_minimum_size = Vector2(0, h)
    return c

# ── Menu ────────────────────────────────────────────────────
var _menu_lvl_lbl   : Label
var _menu_coins_lbl : Label

func _build_menu() -> void:
    menu_panel = _styled_panel(440, 320)
    add_child(menu_panel)
    var v := _vbox(menu_panel)
    v.add_child(_lbl("CYBER DASH", 34, Color(0.00, 0.92, 0.98)))
    v.add_child(_lbl("NEON ESCAPE", 20, Color(0.65, 0.20, 1.00)))
    v.add_child(_spacer(6))
    # Dynamic level info — updated by set_level_info()
    _menu_lvl_lbl   = _lbl("Level 1", 28, Color(0.00, 0.92, 0.98))
    _menu_coins_lbl = _lbl("Collect 100 crystals", 19, Color(0.65, 0.20, 1.00))
    v.add_child(_menu_lvl_lbl)
    v.add_child(_menu_coins_lbl)
    v.add_child(_spacer(10))
    v.add_child(_lbl("Jump: W / Up    Slide: S / Down", 15, Color(0.65, 0.65, 0.65)))
    v.add_child(_spacer(8))
    var btn := _styled_btn("START GAME", 270)
    btn.pressed.connect(func(): start_pressed.emit())
    v.add_child(btn)

func set_level_info(num: int, coins_goal: int) -> void:
    _menu_lvl_lbl.text   = "Level %d" % num
    _menu_coins_lbl.text = "Collect %d coins" % coins_goal

# ── Game Over ───────────────────────────────────────────────
func _build_gameover() -> void:
    gameover_panel = _styled_panel(440, 310)
    gameover_panel.visible = false
    add_child(gameover_panel)
    var v := _vbox(gameover_panel)
    v.add_child(_lbl("GAME OVER", 42, Color(1.0, 0.25, 0.2)))
    go_score_lbl = _lbl("", 20, Color(0.88, 0.88, 0.88))
    v.add_child(go_score_lbl)
    v.add_child(_spacer(10))
    var btn := _styled_btn("RESTART", 230)
    btn.pressed.connect(func(): restart_pressed.emit())
    v.add_child(btn)

# ── Level Complete ──────────────────────────────────────────
func _build_level_complete() -> void:
    level_complete_panel = _styled_panel(460, 310)
    level_complete_panel.visible = false
    add_child(level_complete_panel)
    var v := _vbox(level_complete_panel)
    v.add_child(_lbl("LEVEL COMPLETE!", 36, Color(0.2, 1.0, 0.45)))
    v.add_child(_lbl("", 20, Color(0.85, 0.85, 0.85)))   # placeholder — updated in show_level_complete
    v.add_child(_spacer(10))
    var btn := _styled_btn("NEXT LEVEL  ▶", 260, Color(0.1, 0.6, 0.15))
    btn.pressed.connect(func(): next_level_pressed.emit())
    v.add_child(btn)

# ── You Win ─────────────────────────────────────────────────
func _build_you_win() -> void:
    you_win_panel = _styled_panel(460, 300)
    you_win_panel.visible = false
    add_child(you_win_panel)
    var v := _vbox(you_win_panel)
    v.add_child(_lbl("🏆 YOU WIN! 🏆", 40, Color(1.0, 0.85, 0.0)))
    v.add_child(_lbl("You outran the Robo-Samurai!\nCyber Legend.", 20, Color(0.70, 0.90, 1.00)))
    v.add_child(_spacer(10))
    var btn := _styled_btn("PLAY AGAIN", 240, Color(0.55, 0.1, 0.8))
    btn.pressed.connect(func(): play_again_pressed.emit())
    v.add_child(btn)

# ── Fast Button ─────────────────────────────────────────────
func _setup_fast_button() -> void:
    fast_btn = get_node_or_null("FastButton") as Button
    if not fast_btn:
        fast_btn = Button.new()
        fast_btn.name = "FastButton"
        fast_btn.text = "FAST"
        fast_btn.toggle_mode = true
        fast_btn.focus_mode = Control.FOCUS_NONE
        fast_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        fast_btn.offset_left = -130.0
        fast_btn.offset_top = -80.0
        fast_btn.offset_right = -20.0
        fast_btn.offset_bottom = -25.0
        add_child(fast_btn)

    fast_btn.custom_minimum_size = Vector2(100, 50)
    fast_btn.add_theme_font_size_override("font_size", 20)
    var sbn := StyleBoxFlat.new()
    sbn.bg_color = Color(0.12, 0.14, 0.20, 0.85)
    sbn.border_color = Color(0.3, 0.7, 1.0, 0.9)
    sbn.border_width_left = 2; sbn.border_width_right = 2
    sbn.border_width_top = 2; sbn.border_width_bottom = 2
    sbn.corner_radius_top_left = 8; sbn.corner_radius_top_right = 8
    sbn.corner_radius_bottom_left = 8; sbn.corner_radius_bottom_right = 8
    var sbp := sbn.duplicate() as StyleBoxFlat
    sbp.bg_color = Color(0.0, 0.55, 0.95, 0.95)
    fast_btn.add_theme_stylebox_override("normal", sbn)
    fast_btn.add_theme_stylebox_override("hover", sbn)
    fast_btn.add_theme_stylebox_override("pressed", sbp)

    fast_btn.toggled.connect(_on_fast_toggled)
    fast_btn.button_down.connect(_on_fast_down)
    fast_btn.button_up.connect(_on_fast_up)

func _on_fast_toggled(toggled: bool) -> void:
    if toggled:
        Input.action_press("speed_boost")
    else:
        Input.action_release("speed_boost")

func _on_fast_down() -> void:
    Input.action_press("speed_boost")

func _on_fast_up() -> void:
    if fast_btn and not fast_btn.button_pressed:
        Input.action_release("speed_boost")

func reset_fast_button() -> void:
    if fast_btn:
        fast_btn.button_pressed = false
    if Input.is_action_pressed("speed_boost"):
        Input.action_release("speed_boost")

# ── Public API ──────────────────────────────────────────────
func show_menu() -> void:
    reset_fast_button()
    if fast_btn:
        fast_btn.visible         = false
    menu_panel.visible           = true
    gameover_panel.visible       = false
    level_complete_panel.visible = false
    you_win_panel.visible        = false

func show_gameover(score: int, dist: int) -> void:
    reset_fast_button()
    if fast_btn:
        fast_btn.visible         = false
    go_score_lbl.text            = "Distance: %dm    Score: %d" % [dist, score]
    menu_panel.visible           = false
    gameover_panel.visible       = true
    level_complete_panel.visible = false
    you_win_panel.visible        = false

func show_level_complete(level_num: int, coins: int, diamonds: int) -> void:
    reset_fast_button()
    if fast_btn:
        fast_btn.visible         = false
    var v := level_complete_panel.get_child(0) as VBoxContainer
    var info := v.get_child(1) as Label
    info.text = "Level %d  |  Coins: %d  |  Diamonds: %d (bonus)" % [level_num, coins, diamonds]
    menu_panel.visible           = false
    gameover_panel.visible       = false
    level_complete_panel.visible = true
    you_win_panel.visible        = false

func show_you_win() -> void:
    reset_fast_button()
    if fast_btn:
        fast_btn.visible         = false
    menu_panel.visible           = false
    gameover_panel.visible       = false
    level_complete_panel.visible = false
    you_win_panel.visible        = true

func hide_all() -> void:
    menu_panel.visible           = false
    gameover_panel.visible       = false
    level_complete_panel.visible = false
    you_win_panel.visible        = false
    if fast_btn:
        fast_btn.visible         = true

