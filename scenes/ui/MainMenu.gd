extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options
@onready var chkbnt_screen_size: CheckButton = $Options/Label/chkbntScreenSize



func _ready():
	main_buttons.visible = true
	options.visible = false
	chkbnt_screen_size.button_pressed = true


func _on_btn_exit_pressed() -> void:
	self.get_tree().quit()


func _on_btn_options_pressed() -> void:
	print("pressed btnOptions")
	main_buttons.visible = false
	options.visible = true


func _on_btn_start_pressed() -> void:
	print("pressed btnStart")


func _on_btn_options_back_pressed() -> void:
	_ready()


func _on_chkbnt_screen_size_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
