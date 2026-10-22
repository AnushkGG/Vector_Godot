extends Node2D

var coins = 0
var diamonds = 0
@onready var ui_label = $CanvasLayer/HUD/Label

func _ready():
    update_ui()

func add_coin():
    coins += 1
    update_ui()
    check_progression()

func add_diamond():
    diamonds += 1
    update_ui()
    check_progression()

func update_ui():
    ui_label.text = "Coins: %d/50 | Diamonds: %d/2" % [coins, diamonds]

func check_progression():
    if coins >= 50 and diamonds >= 2:
        ui_label.text = "LEVEL 2 READY!"
        get_tree().paused = true
