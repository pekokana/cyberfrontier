# MissionSelectUI.gd
extends Control

# @onready変数を新しいノード名に合わせて更新
@onready var mission_list_grid = $HBoxContainer/ListPanel/VBoxContainer/ScrollContainer/MissionListGrid
@onready var mission_title_label = $HBoxContainer/DetailsPanel/VBoxContainer/MissionTitle
@onready var mission_description_label = $HBoxContainer/DetailsPanel/VBoxContainer/ScrollContainer/MissionDescription
@onready var btn_start_mission: Button = $HBoxContainer/DetailsPanel/VBoxContainer/btnStartMission

# MissionManagerからミッションデータを取得するために使用
const MISSION_MANAGER_PATH = "/root/MissionManager"
# RootSceneへの確実なアクセスパス
const ROOT_SCENE_PATH = "/root/RootScene"


func _ready():
	# UIを画面の中央に配置
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# MissionManagerから全ミッションデータを取得
	var mission_manager = get_node(MISSION_MANAGER_PATH)
	if not is_instance_valid(mission_manager):
		printerr("FATAL ERROR: MissionManager node not found at ", MISSION_MANAGER_PATH)
		return

	var missions = mission_manager.loaded_missions
	
	# 詳細表示を初期化
	mission_title_label.text = "ミッションタイトル"
	mission_description_label.text = "ミッションを選択すると、ここに詳細が表示されます。"

	# GridContainer内の既存の子ノードをクリア（シーンのリロード時などに備えて）
	for child in mission_list_grid.get_children():
		child.queue_free()

	if missions.is_empty():
		var label = Label.new()
		label.text = "Error: No missions found in res://missions/"
		mission_list_grid.add_child(label)
		# 1列目を幅いっぱいに広げる（2列目は表示しない）
		mission_list_grid.set_column_expand(0, true) 
		return

	# ==================================================
	# GridContainerのヘッダーを追加
	# 💡 エラー修正: header_list_grid -> mission_list_grid に変更
	# ==================================================
	
	# 列1: ミッション名 / ID
	var header_title = Label.new()
	header_title.text = "ミッション名 / ID"
	header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mission_list_grid.add_child(header_title)
	
	# 列2: 難易度
	var header_difficulty = Label.new()
	header_difficulty.text = "難易度"
	header_difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_list_grid.add_child(header_difficulty)

	# 各ミッションのテーブル行を生成
	for id in missions.keys():
		var mission = missions[id]
		create_mission_row(id, mission)

# 💡 ミッションのテーブル行（ボタンとラベル）を生成する関数
func create_mission_row(mission_id: String, data: Dictionary):
	# 1. ミッション名（ボタンとして機能）
	var button = Button.new()
	# MissionManager.gd のログ出力から mission_id が正しいことがわかるため、mission_idを使用
	button.text = "%s (%s)" % [data.get("title", "Untitled"), mission_id] 
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT # 左寄せに設定
	
	# ボタンが押されたら、詳細表示とミッション選択を処理
	button.pressed.connect(Callable(self, "_on_mission_selected").bind(mission_id, data))
	
	mission_list_grid.add_child(button)

	# 2. 難易度（ラベルとして表示）
	var difficulty_label = Label.new()
	difficulty_label.text = data.get("difficulty", "N/A")
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER # 中央揃えに設定

	mission_list_grid.add_child(difficulty_label)

# 💡 ミッション選択時（ボタンクリック時）の処理
func _on_mission_selected(mission_id: String, data: Dictionary):
	# --- 1. 詳細パネルの更新 ---
	# タイトルを更新
	mission_title_label.text = data.get("title", "Untitled") + " [" + mission_id + "]"
	
	# 概要を更新
	var description = data.get("description", "このミッションの概要が定義されていません。")
	mission_description_label.text = description

	print("Mission selected: ", mission_id, ". Details displayed.")

	# --- 2. 実際のミッション開始処理 (後で実装するためにコメントアウト/プレースホルダー) ---
	# ここでミッション開始ボタンを有効化したり、詳細パネルに「ミッション開始」ボタンを配置したりする

# 💡 メインメニューに戻るボタンが押されたときの処理
func _on_btn_back_main_menu_pressed() -> void:
	print("Back button pressed: Transitioning to MainMenuUI")
	
	# =======================================================
	# 💡 エラー修正: get_root_scene() -> 絶対パスでのノード取得に変更
	# =======================================================
	var root_scene = get_node(ROOT_SCENE_PATH)
	
	if is_instance_valid(root_scene) and root_scene.has_method("start_main_menu_mode"):
		# 💡 RootSceneの遷移関数を呼び出す
		root_scene.start_main_menu_mode()
	else:
		print("ERROR: Could not find RootScene or start_main_menu_mode method.")


func _on_btn_start_mission_pressed(mission_id: String) -> void:
	print("Attempting to start mission: ", mission_id)
	var root_scene = get_node(ROOT_SCENE_PATH)
	if is_instance_valid(root_scene) and root_scene.has_method("start_mission"):
		# RootSceneにミッション実行を通知
		root_scene.start_mission(mission_id)
	else:
		printerr("ERROR: RootScene node not found or 'start_mission' method is missing.")
