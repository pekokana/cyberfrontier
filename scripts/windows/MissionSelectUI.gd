# MissionSelectUI.gd
extends Control

@onready var mission_list_container = $PanelContainer/VBoxContainer/ScrollContainer/MissionListContainer

func _ready():
	# UIを画面の中央に配置
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# MissionManagerから全ミッションデータを取得
	var missions = MissionManager.loaded_missions
	
	if missions.is_empty():
		var label = Label.new()
		label.text = "Error: No missions found in res://missions/"
		mission_list_container.add_child(label)
		return

	# 各ミッションのボタンを生成
	for id in missions.keys():
		var mission = missions[id]
		create_mission_button(id, mission)

func create_mission_button(mission_id: String, data: Dictionary):
	var button = Button.new()


	
	print("mission_id > " + data.get("mission_id", "N/A"))
	print("title > " + data.get("title", "Untitled"))
	print("difficulty > " + data.get("difficulty", "N/A"))

	# メタデータを使ってボタンのテキストを作成
	button.text = "%s - %s (%s)" % [
		data.get("mission_id", "N/A"), 
		data.get("title", "Untitled"), 
		data.get("difficulty", "N/A")
	]
	
	# ボタンが押されたら、RootSceneにミッション開始を通知
	button.pressed.connect(Callable(self, "_on_mission_selected").bind(mission_id))
	
	mission_list_container.add_child(button)

func _on_mission_selected(mission_id: String):
	print("Mission selected: ", mission_id)
	
	# RootSceneにアクセスしてミッションを開始させる (Global.gdにRootSceneの参照が必要な場合がある)
	# ここでは簡単な方法として、ノードツリーをたどってRootSceneの関数を直接呼び出す
	var root_scene = get_tree().get_root().get_child(0) # 通常はRootSceneが最初のノード
	if root_scene.has_method("start_mission"):
		root_scene.start_mission(mission_id)
		# 選択UIを閉じる
		queue_free()
