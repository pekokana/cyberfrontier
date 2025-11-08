extends Node2D

@onready var mission_manager = get_node("/root/MissionManager")

# 💡 修正: シーンのpreloadは全て 'const' で大文字表記に統一します
const MDI_WINDOW_SCENE = preload("res://scenes/windows/mdi_window.tscn")
const TERMINAL_SCENE = preload("res://scenes/windows/terminal_ui.tscn")
const NETWORKMAP_SCENE = preload("res://scenes/windows/NetworkMapUI.tscn")
const SIDEBAR_SCENE = preload("res://scenes/ui/Sidebar.tscn")
const MISSION_SELECT_SCENE = preload("res://scenes/ui/MissionSelectUI.tscn")
const MAIN_MENU_SCENE = preload("res://scenes/ui/MainMenu.tscn")
const MISSION_EXECUTION_SCENE = preload("res://scenes/ui/MissionExecutionUI.tscn")

# 開いているウィンドウを管理する辞書（重複防止用）
var open_windows: Dictionary = {}

# アニメーションを制御するノード (SidebarContainerの子として追加するのがベスト)
@onready var ui_layer: CanvasLayer = $UI_Layer
@onready var ui_holder: Control = $UI_Layer/UI_Holder
@onready var sidebar_toggle: TextureButton = $UI_Layer/SidebarToggle
@onready var btn_back_mission_select: Button = $UI_Layer/btnBackMissionSelect
@onready var btn_start_mission: Button = $HBoxContainer/DetailsPanel/VBoxContainer/btnStartMission

var sidebar_instance: Control = null # <--- Sidebarインスタンスを保持する変数
var current_ui_instance: Control = null

var current_ui_scene: Control = null

# サイドバーの幅とアニメーション時間をここで定数として定義し、sidebar.gdと同期させる
const SIDEBAR_WIDTH = Global.SIDEBAR_WIDTH
const TWEEN_DURATION = Global.TWEEN_DURATION

var sidebar_expanded: bool = false
const COLLAPSED_WIDTH = 20.0
const EXPANDED_WIDTH = 150.0 # 展開後の幅

func _ready():
	# 1.Sidebarインスタンスを作成し、UI_Layerの子として追加
	var sidebar_ui = SIDEBAR_SCENE.instantiate() # 💡 修正: SIDEBAR_SCENEを使用
	if is_instance_valid(ui_layer):
		$UI_Layer.add_child(sidebar_ui)
	else:
		print("FATAL ERROR: UI_Layer is null! Cannot add Sidebar.")
	
	if is_instance_valid(sidebar_toggle):
		sidebar_toggle.visible = false # 👈 エラー回避
	else:
		print("FATAL ERROR: sidebar_toggle is null! Check the path $UI_Layer/SidebarToggle.")
	sidebar_instance = sidebar_ui
	sidebar_instance.visible = false # 初期状態は非表示とする
	
	if is_instance_valid(btn_back_mission_select):
		btn_back_mission_select.visible = false
	else:
		print("FATAL ERROR: btn_back_mission_select is null! Check the path $UI_Layer/btnBackMissionSelect.")


	# 2.アプリ起動ときはMission Select/Main Menuのいずれかから開始
	#navigate_to_mission_select()
	start_main_menu_mode()

# ----------
# ヘルパーメソッド（UI切り替えの核とするロジック）
# ----------
func get_root_scene():
	# 💡 確実にRootSceneを取得するためのヘルパー
	return get_node("/root/RootScene")

# 💡 追加: 既存のUIとウィンドウを全てクリーンアップする関数
func _clear_ui_and_windows():
	# 古い全画面UIを削除
	if is_instance_valid(current_ui_instance):
		current_ui_instance.queue_free()
		current_ui_instance = null
		
	# 開いているMDIウィンドウを全て削除
	for id in open_windows.keys():
		if is_instance_valid(open_windows[id]):
			open_windows[id].queue_free()
	open_windows.clear()
	
func _set_current_ui(new_ui: Control):
	# 1.古いUIを削除
	if is_instance_valid(current_ui_instance):
		current_ui_instance.queue_free()
		
	# 2.新しいUIをUI_Holderに追加
	if is_instance_valid(ui_holder):
		ui_holder.add_child(new_ui)
	else:
		print("FATAL ERROR: UI_Holder is null! Cannot add UI_Holder.")
	current_ui_instance = new_ui
	# Full Rectプリセットで親(UI_Holder)全体に広げる
	new_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	
# ミッション選択画面へ移行(MainMenuUIから呼び出される）
func navigate_to_mission_select():
	# 💡 修正: _clear_ui_and_windowsを呼び出し、クリーンアップを任せる
	_clear_ui_and_windows()
	
	# UI_HolderにMissionSelectUIをロード
	var mission_select_instance = MISSION_SELECT_SCENE.instantiate() # 💡 修正: 定数 MISSION_SELECT_SCENEを使用
	_set_current_ui(mission_select_instance) # 💡 修正: タイポ mission_select_instalce を修正
	
	if is_instance_valid(sidebar_toggle):
		sidebar_toggle.visible = false
	if is_instance_valid(sidebar_instance):
		sidebar_instance.visible = false # Sidebarも非表示とする
	if is_instance_valid(btn_back_mission_select):
		btn_back_mission_select.visible = false

# 💡 メインメニュー画面へ移行 (アプリ起動時や、MissionSelectUIの「戻る」ボタンから呼び出される)
func start_main_menu_mode():
	# UIとMDIウィンドウを全てクリア
	_clear_ui_and_windows()
	
	# UI_HolderにMainMenuUIをロード
	var main_menu_instance = MAIN_MENU_SCENE.instantiate()
	_set_current_ui(main_menu_instance)
	
	# Sidebarとトグルボタンは非表示
	if is_instance_valid(sidebar_toggle):
		sidebar_toggle.visible = false
	if is_instance_valid(sidebar_instance):
		sidebar_instance.visible = false
	if is_instance_valid(btn_back_mission_select):
		btn_back_mission_select.visible = false

# ミッション開始関数
func start_mission(mission_id: String):
	# 1. MissionManagerが有効か確認
	if not is_instance_valid(mission_manager):
		printerr("FATAL ERROR: MissionManager is not valid or not in the scene tree.")
		return
		
	# 2. MissionManagerからミッションデータを取得
	# 💡 MissionManager.gdに追加した get_mission_data 関数を使用
	if not mission_manager.has_method("get_mission_data"):
		printerr("ERROR: MissionManager is missing 'get_mission_data' method. Transition failed.")
		return
		
	var mission_data = mission_manager.get_mission_data(mission_id)
	
	if mission_data.is_empty():
		printerr("Error: Mission data not found for ID:", mission_id)
		return
	
	# 3. 現在のUIを解放
	if is_instance_valid(current_ui_scene):
		current_ui_scene.queue_free()

	# 4. MissionExecutionUIシーンをインスタンス化
	if MISSION_EXECUTION_SCENE == null:
		printerr("ERROR: MISSION_EXECUTION_SCENE is null. Check preload path.")
		return

	# UIとMDIウィンドウを全てクリア
	_clear_ui_and_windows()
	
	# UI_HolderにMainMenuUIをロード
	#var main_menu_instance = MAIN_MENU_SCENE.instantiate()
	var mission_ui = MISSION_EXECUTION_SCENE.instantiate()
	_set_current_ui(mission_ui)
	
	## 5. シーンツリーに追加し、current_ui_sceneを更新
	#add_child(mission_ui)
	#current_ui_scene = mission_ui
	
	# 6. MissionExecutionUIをミッションデータで初期化
	if mission_ui.has_method("initialize_mission"):
		mission_ui.initialize_mission(mission_id, mission_data)
	else:
		printerr("Error: MissionExecutionUI is missing initialize_mission method.")


# 💡 ウィンドウを開く汎用関数
func open_window(window_id: String, content_scene: PackedScene, initial_position: Vector2 = Vector2(50, 50)):
	if open_windows.has(window_id) and is_instance_valid(open_windows[window_id]):
		# すでに開いている場合は最前面に移動して終了
		open_windows[window_id].grab_focus()
		return
	
	var mdi_window = MDI_WINDOW_SCENE.instantiate() # 💡 修正: MDI_WINDOW_SCENEを使用
	#self.add_child(mdi_window) # RootSceneの子として追加
	# UI_Layerの子供として追加する
	if is_instance_valid(ui_layer):
		$UI_Layer.add_child(mdi_window)
	else:
		print("ERROR: UI_layer is null! Cannot open window.")
		mdi_window.queue_free()
		return
	
	# ... (以降の open_window 関数は変更なし)

	mdi_window.position = initial_position
	
	# 初期化
	mdi_window.initialize(window_id, content_scene)
	open_windows[window_id] = mdi_window
	
	# ウィンドウが閉じられた時の処理を設定
	mdi_window.close_requested.connect(Callable(self, "_on_window_closed").bind(window_id))

	# ターミナルが起動した場合はフォーカスを設定
	if window_id == "Terminal" and mdi_window.has_node("ContentContainer/TerminalUI"):
		var term = mdi_window.get_node("ContentContainer/TerminalUI")
		if term.has_node("InputLine"):
			term.get_node("InputLine").grab_focus()

	# マップウィンドウが開かれたらロード処理を呼び出す
	if window_id == "Network Map":
		# MDIWindow -> ContentContainer -> NetworkMapUI -> NetworkMap へのパスを辿る
		var network_map_ui = mdi_window.get_node("ContentContainer").get_child(0) # ContentContainerの子は NetworkMapUI のはず
		var network_manager = network_map_ui.find_child("NetworkMap")
		
		if is_instance_valid(network_manager):
			# 🚨 テストのため、パスを 'res://' に変更することを推奨します
			network_manager.load_mission("res://missions/mission_01.json")

func _on_window_closed(window_id):
	# ウィンドウが閉じられたら管理リストから削除
	open_windows.erase(window_id)

# 💡 サイドバーの開閉処理は大きな変更なし
func _on_sidebar_toggle_pressed() -> void:
	if not is_instance_valid(sidebar_instance):
		return

	# 1. sidebar_instanceの開閉アニメーションを開始し、新しい状態（is_open_now）を取得
	var is_open_now = sidebar_instance.toggle_sidebar()
	
	# 2. トグルボタンをアニメーションさせるためのTweenを作成
	var tween = create_tween()
	
	# 3. 目標位置を計算
	# 閉じる時（false）: X=0 (画面端)
	# 開く時（true）: X=SIDEBAR_WIDTH (100.0)
	var target_x = SIDEBAR_WIDTH if is_open_now else 0.0
	
	# 4. sidebar_toggleノードのX座標をアニメーション
	tween.tween_property(sidebar_toggle, "position", Vector2(target_x, sidebar_toggle.position.y), TWEEN_DURATION)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)


func _on_btn_back_mission_select_pressed() -> void:
	print("Back button pressed: Transitioning to MissionSelectUI")
	
	navigate_to_mission_select()

# -------------------------------------------------------------
# 💡 実行画面から戻るための関数 (ExitButton用)
# -------------------------------------------------------------
func start_mission_select_mode():
	# 1. 現在のUI (MissionExecutionUI) を解放
	if is_instance_valid(current_ui_scene):
		print("DEBUG: [RootScene] Attempting to free old UI:", current_ui_scene.name)
		# 💡 current_ui_sceneを解放
		current_ui_scene.queue_free() 
		# 💡 解放後、参照をクリア
		current_ui_scene = null
	else:
		print("DEBUG: [RootScene] No current_ui_scene to free.")
		
	# 2. MissionSelectUIシーンをインスタンス化し、表示
	if MISSION_SELECT_SCENE == null:
		printerr("ERROR: MISSION_SELECT_SCENE is null. Check preload path.")
		return
		
	var select_ui = MISSION_SELECT_SCENE.instantiate()
	# 💡 修正: RootSceneではなく、ui_holderの子として追加する
	ui_holder.add_child(select_ui) 
	current_ui_scene = select_ui
	
	print("Transitioning to MissionSelectUI.")
