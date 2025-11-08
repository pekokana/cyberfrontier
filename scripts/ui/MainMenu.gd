extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options
@onready var chkbnt_screen_size: CheckButton = $Options/Label/chkbntScreenSize

func _ready():
	main_buttons.visible = true
	options.visible = false
	chkbnt_screen_size.button_pressed = true

	# 💡 _ready()の最後にツリー全体を出力
	print("====================================")
	print("Current Scene Tree Structure:")
	print("====================================")
	# シーンツリーのルートから処理を開始
	Global.print_node_tree(get_tree().get_root())
	print("====================================")



func _on_btn_exit_pressed() -> void:
	self.get_tree().quit()


func _on_btn_options_pressed() -> void:
	print("pressed btnOptions")
	main_buttons.visible = false
	options.visible = true


func _on_btn_start_pressed() -> void:
	print("pressed btnStart: Transitioning to MissionSelectUI")
		
	# RootSceneのインスタンスを取得（SceneTreeのルートの子ノードであると仮定）
	#var root_scene = get_tree().get_root().find_child("RootScene", true)
	var root_scene = get_node("/root/RootScene")

	if is_instance_valid(root_scene):
		if root_scene.has_method("navigate_to_mission_select"):
			# 💡 画面遷移を実行
			root_scene.navigate_to_mission_select()
		else:
			print("ERROR: RootScene found, but method 'navigate_to_mission_select' is missing in root_scene.gd.")
	else:
		# エラーメッセージを分かりやすく
		print("ERROR: Could not find RootScene node in the tree.")
		print("Is RootScene the main scene?")


func _on_btn_options_back_pressed() -> void:
	_ready()


func _on_chkbnt_screen_size_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
