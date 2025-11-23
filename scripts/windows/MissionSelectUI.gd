# MissionSelectUI.gd
extends Control
# @onready変数を新しいノード名に合わせて更新
@onready var mission_list_grid = $HBoxContainer/ListPanel/VBoxContainer/ScrollContainer/MissionListGrid
@onready var mission_title_label = $HBoxContainer/DetailsPanel/VBoxContainer/MissionTitle
@onready var mission_description_label = $HBoxContainer/DetailsPanel/VBoxContainer/ScrollContainer/MissionDescription
@onready var btn_start_mission = $HBoxContainer/DetailsPanel/VBoxContainer/btnStartMission # 💡 追加したボタンの参照

# MissionManagerからミッションデータを取得するために使用
const MISSION_MANAGER_PATH = "/root/MissionManager"
# RootSceneへの確実なアクセスパス
const ROOT_SCENE_PATH = "/root/RootScene"

# 難易度を並べ替えるためのリスト (ソート順序を定義するため)
const DIFFICULTY_ORDER = ["Easy", "Medium", "Hard", "Expert", "Unknown"]


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var mission_manager = get_node(MISSION_MANAGER_PATH)
	if not is_instance_valid(mission_manager):
		printerr("FATAL ERROR: MissionManager node not found at ", MISSION_MANAGER_PATH)
		return

	var missions = mission_manager.loaded_missions
	
	# 詳細表示を初期化
	mission_title_label.text = "ミッションタイトル"
	mission_description_label.text = "ミッションを選択すると、ここに詳細が表示されます。"
	btn_start_mission.disabled = true
	
	# GridContainer内の既存の子ノードをクリア
	for child in mission_list_grid.get_children():
		child.queue_free()

	if missions.is_empty():
		var label = Label.new()
		label.text = "Error: No missions found."
		mission_list_grid.add_child(label) 
		return

	# ==================================================
	# 💡 難易度ごとにミッションをグループ化し、存在する難易度を抽出
	# ==================================================
	var missions_by_difficulty: Dictionary = {}
	var present_difficulties: Array = [] 
	
	for id in missions.keys():
		var mission = missions[id]
		var difficulty = mission.get("difficulty", "Unknown") 
		
		if not missions_by_difficulty.has(difficulty):
			missions_by_difficulty[difficulty] = []
			present_difficulties.append(difficulty) 
			
		missions_by_difficulty[difficulty].append({"id": id, "data": mission})

	# ==================================================
	# 💡 存在する難易度を DIFFICULTY_ORDER に基づいてソートする
	# ==================================================
	var sorted_difficulties: Array = []
	for ordered_difficulty in DIFFICULTY_ORDER:
		if present_difficulties.has(ordered_difficulty):
			sorted_difficulties.append(ordered_difficulty)

	# ==================================================
	# 💡 ソートされた難易度リストに基づいてUIに表示 (折りたたみ機能付き)
	# ==================================================
	for difficulty in sorted_difficulties: 
		var mission_list: Array = missions_by_difficulty[difficulty]
		create_difficulty_group(difficulty, mission_list)

	# GridContainerの列数を1に設定し、VBoxContainerのように動作させる
	mission_list_grid.columns = 1
	#mission_list_grid.set_column_expand(0, true) 

	## 💡 _ready()の最後にツリー全体を出力
	#print("====================================")
	#print("★MissionSelectUI - Current Scene Tree Structure:")
	#print("====================================")
	## シーンツリーのルートから処理を開始
	#Global.print_node_tree(get_tree().get_root())
	#print("====================================")



# 💡 難易度ヘッダーと折りたたみコンテナを生成する新しい関数
func create_difficulty_group(difficulty_name: String, mission_list: Array):
	# 1. 難易度ヘッダーボタン（折りたたみトグルとして機能）
	var header_button = Button.new()
	header_button.text = "▼ " + difficulty_name # 最初に展開状態 (▼) で表示
	header_button.add_theme_font_size_override("font_size", 20)
	header_button.flat = true 
	header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# 2. ミッションボタンを格納するコンテナ
	var mission_vbox = VBoxContainer.new()
	mission_vbox.name = "Missions_" + difficulty_name
	
	# 3. 接続: ヘッダーがクリックされたら、ミッションコンテナの可視性を切り替える
	header_button.pressed.connect(Callable(self, "_on_difficulty_header_toggled").bind(header_button, mission_vbox))
	
	# GridContainerにヘッダーとコンテナを追加
	mission_list_grid.add_child(header_button)
	mission_list_grid.add_child(mission_vbox)

	# 4. コンテナ内にミッションボタンを生成
	for item in mission_list:
		create_mission_button_in_group(mission_vbox, item.id, item.data)
		
	# 初期状態で展開
	mission_vbox.visible = true 


# 💡 VBoxContainer の子としてミッションボタンを生成 (難易度表示は不要)
func create_mission_button_in_group(parent_container: VBoxContainer, mission_id: String, data: Dictionary):
	var button = Button.new()
	# 表示形式: 「・ ミッション名 (ID)」
	button.text = "  ・ %s (%s)" % [data.get("title", "Untitled"), mission_id]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	button.add_theme_font_size_override("font_size", 16)
	button.flat = true
	
	# ボタンが押されたら、詳細表示を処理
	button.pressed.connect(Callable(self, "_on_mission_selected").bind(mission_id, data))
	
	parent_container.add_child(button)


# 💡 折りたたみ処理の本体
func _on_difficulty_header_toggled(header_button: Button, mission_vbox: VBoxContainer):
	# 可視性をトグル
	mission_vbox.visible = not mission_vbox.visible
	
	# ボタンのテキストを切り替えて、開閉状態を視覚的にフィードバック
	if mission_vbox.visible:
		# 展開時
		header_button.text = header_button.text.replace("▶", "▼")
	else:
		# 収縮時
		header_button.text = header_button.text.replace("▼", "▶")


# 💡 ミッション選択時（ボタンクリック時）の処理
func _on_mission_selected(mission_id: String, data: Dictionary):
	# --- 1. 詳細パネルの更新 ---
	mission_title_label.text = data.get("title", "Untitled") + " [" + mission_id + "]"
	
	var difficulty = data.get("difficulty", "N/A")
	var description = "難易度: %s\n\n%s" % [difficulty, data.get("description", "このミッションの概要が定義されていません。")]
	
	print("Mission Description Content:", description)
	
	mission_description_label.text = description

	# --- 2. ミッション開始ボタンを有効化 ---
	if is_instance_valid(btn_start_mission):
		btn_start_mission.disabled = false 
	
		# 古い接続を切断
		if btn_start_mission.pressed.is_connected(Callable(self, "_on_start_mission_pressed")):
			btn_start_mission.pressed.disconnect(Callable(self, "_on_start_mission_pressed"))
		
		# 新しいミッションIDをバインドして接続
		btn_start_mission.pressed.connect(Callable(self, "_on_start_mission_pressed").bind(mission_id))


# 💡 ミッション実行ボタンが押されたときの処理
func _on_start_mission_pressed(mission_id: String) -> void:
	print("Attempting to start mission: ", mission_id)
	
	var root_scene = get_node(ROOT_SCENE_PATH)
	
	if is_instance_valid(root_scene) and root_scene.has_method("start_mission"):
		root_scene.start_mission(mission_id)
	else:
		printerr("ERROR: RootScene node not found or 'start_mission' method is missing.")


# 💡 メインメニューに戻るボタンが押されたときの処理
func _on_btnBackMainMenu_pressed() -> void:
	print("Back button pressed: Transitioning to MainMenuUI")
	
	var root_scene = get_node(ROOT_SCENE_PATH)
	
	if is_instance_valid(root_scene) and root_scene.has_method("start_main_menu_mode"):
		root_scene.start_main_menu_mode()
	else:
		print("ERROR: Could not find RootScene or start_main_menu_mode method.")


func _on_btn_back_main_menu_pressed() -> void:
	print("Back button pressed: Transitioning to MainMenuUI")
	
	var root_scene = get_node(ROOT_SCENE_PATH)
	
	if is_instance_valid(root_scene) and root_scene.has_method("start_main_menu_mode"):
		root_scene.start_main_menu_mode()
	else:
		print("ERROR: Could not find RootScene or start_main_menu_mode method.")
