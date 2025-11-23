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
#@onready var btn_start_mission: Button = $HBoxContainer/DetailsPanel/VBoxContainer/btnStartMission

var sidebar_instance: Control = null # <--- Sidebarインスタンスを保持する変数
var current_ui_instance: Control = null

var current_ui_scene: Control = null

# サイドバーの幅とアニメーション時間をここで定数として定義し、sidebar.gdと同期させる
const SIDEBAR_WIDTH = Global.SIDEBAR_WIDTH
const TWEEN_DURATION = Global.TWEEN_DURATION

var sidebar_expanded: bool = false
const COLLAPSED_WIDTH = 20.0
const EXPANDED_WIDTH = 150.0 # 展開後の幅


func _vfstest():
	# 模擬JSONデータ
	var mock_initial_files = [
		{"path": "/home/user/README.txt", "type": "text", "content": "Welcome to CyberFrontier."},
		# 親ディレクトリ（/home/user/logs）は自動で作成される
		{"path": "/home/user/logs/auth.log", "type": "text", "content": "Failed login attempt from 5.188.230.12\nAccepted login from 192.168.1.1\nFailed login attempt from 5.188.230.12"}
	]
	
	# 手動でのディレクトリ作成は削除
	# var logs_node = VFSCore.VFSNode.new("logs", VFSCore.VFSNode.NodeType.DIR, "/home/user/logs")
	# VFSCore.root_node.children["logs"] = logs_node
	
	# load_mission_setupがすべてを処理
	VFSCore.load_mission_setup(mock_initial_files)
	
	# テスト: ls コマンドの出力
	print("--- LS Test ---")
	var home_contents = VFSCore.get_directory_contents("/home/user")
	print(home_contents) # Expected: logs, README.txt

	# テスト: cat コマンドの出力
	print("--- CAT Test ---")
	var log_content = VFSCore.read_file("/home/user/logs/auth.log")
	print(log_content)


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

	# vfs-test
	_vfstest()

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

	# 1. 古い全画面UIを削除
	if is_instance_valid(current_ui_instance):
		print("DEBUG: [Cleanup] Clearing current_ui_instance:", current_ui_instance.name)
		current_ui_instance.queue_free()
		current_ui_instance = null
		
	# 2. 開いているMDIウィンドウを全て削除 (オープンウィンドウ辞書に基づく)
	for id in open_windows.keys():
		if is_instance_valid(open_windows[id]):
			print("DEBUG: [Cleanup] Clearing open_windows dict entry:", id)
			open_windows[id].queue_free()
	open_windows.clear()
	
	# 3. 【強制クリーンアップ強化】UI_Layer直下の動的な子ノードをすべて解放
	if is_instance_valid(ui_layer):
		# 永続的に残すべきノードのリストを作成
		# (ui_holder, sidebar_toggle, btn_back_mission_selectはシーンツリーで定義されている)
		var persistent_nodes = [ui_holder, sidebar_toggle, btn_back_mission_select]
		
		# _ready() で動的に追加された sidebar_instance もリストに追加
		if is_instance_valid(sidebar_instance):
			persistent_nodes.append(sidebar_instance)
		
		# 💡 get_children()の配列をコピーし、逆順に反復処理することで、
		#    ノード解放によるツリー構造の変化を安全に扱う
		var children_to_check = ui_layer.get_children().duplicate()

		
		for child in children_to_check:
			# ノードがまだ有効で、解放待ちでないことを確認
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				
				# 永続ノードリストに含まれているかチェック
				if not persistent_nodes.has(child):
					# 💡 強制解放対象のノード名を出力
					print("FATAL DEBUG: [Cleanup] FORCIBLY FREEING UNWANTED NODE:", child.name, " (Type:", child.get_class(), ")")
					child.queue_free()

	# 💡 4. 【追加の修正】RootSceneノード(self)直下のMDIウィンドウを強制解放
	# MDIウィンドウが RootScene (self) の直下に追加された場合の対策
	var root_node = get_tree().get_root()
	var root_children = root_node.get_children().duplicate()
	
	# ルートの子ノードをすべてチェック
	for child in root_children:
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			
			# 永続ノード（Global, MissionManager, RootScene）ではないノードを解放
			if child.get_name() != "Global" \
				and child.get_name() != "MissionManager" \
				and child.get_name() != "VFSCore" \
				and child.get_name() != "RootScene" \
				and child.get_name() != "MissionState"\
				and child.get_name() != "CF_NetworkService":
				
				# Windowノード（MDIウィンドウ）か、その他の不要なグローバルノードを解放
				print("FATAL DEBUG: [Cleanup] FORCIBLY FREEING ROOT NODE CHILD (MDI Window):", child.name, " (Type:", child.get_class(), ")")
				child.queue_free()

	# 💡 処理終了後、シーンツリー全体をログ出力（デバッグ用）
	print("=========================================================")
	print("Cleanup finished. Dumping current UI_Layer children:")
	if is_instance_valid(ui_layer):
		# UI_Layer の残っている子ノード名を出力して、MDIウィンドウが残っていないか確認
		for child in ui_layer.get_children():
			print("  - REMAINING:", child.name, " (Type:", child.get_class(), ")")
	print("=========================================================")

	
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
#func open_window(window_id: String, content_scene: PackedScene, initial_position: Vector2 = Vector2(50, 50)):
	#if open_windows.has(window_id) and is_instance_valid(open_windows[window_id]):
		## すでに開いている場合は最前面に移動して終了
		#open_windows[window_id].grab_focus()
		#return
	#
	#var mdi_window = MDI_WINDOW_SCENE.instantiate() # 💡 修正: MDI_WINDOW_SCENEを使用
	##self.add_child(mdi_window) # RootSceneの子として追加
	## UI_Layerの子供として追加する
	#if is_instance_valid(ui_layer):
		#$UI_Layer.add_child(mdi_window)
	#else:
		#print("ERROR: UI_layer is null! Cannot open window.")
		#mdi_window.queue_free()
		#return
	#
	## ... (以降の open_window 関数は変更なし)
#
	#mdi_window.position = initial_position
	#
	## 初期化
	#mdi_window.initialize(window_id, content_scene)
	#open_windows[window_id] = mdi_window
	#
	## ウィンドウが閉じられた時の処理を設定
	#mdi_window.close_requested.connect(Callable(self, "_on_window_closed").bind(window_id))
#
	## ターミナルが起動した場合はフォーカスを設定
	#if window_id == "Terminal" and mdi_window.has_node("ContentContainer/TerminalUI"):
		#var term = mdi_window.get_node("ContentContainer/TerminalUI")
		#if term.has_node("InputLine"):
			#term.get_node("InputLine").grab_focus()
#
	## マップウィンドウが開かれたらロード処理を呼び出す
	#if window_id == "Network Map":
		## MDIWindow -> ContentContainer -> NetworkMapUI -> NetworkMap へのパスを辿る
		#var network_map_ui = mdi_window.get_node("ContentContainer").get_child(0) # ContentContainerの子は NetworkMapUI のはず
		#var network_manager = network_map_ui.find_child("NetworkMap")
		#
		#if is_instance_valid(network_manager):
			## 🚨 テストのため、パスを 'res://' に変更することを推奨します
			#network_manager.load_mission("res://missions/mission_01.json")

func open_window(window_type: String, window_title: String, mission_id: String) -> void:
	# 1. 既に開いているかチェック
	if open_windows.has(window_title):
		# 既に開いている場合は前面に移動
		var existing_window = open_windows[window_title]
		if is_instance_valid(existing_window):
			existing_window.top_level = false # 💡 MDIWindowがWindowクラスの場合、CanvasLayerの子にするときはtop_level=falseが必要
			existing_window.z_index = 100 
			existing_window.top_level = true # 💡 再度top_level=trueにして最前面に移動
		return
	
	var content_scene: PackedScene
	
	match window_type:
		"Terminal":
			content_scene = TERMINAL_SCENE
		"NetworkMap":
			content_scene = NETWORKMAP_SCENE
		_:
			printerr("ERROR: Unknown window type:", window_type)
			return
	
	# MDIウィンドウ（Windowノード）のインスタンス化
	var mdi_window = MDI_WINDOW_SCENE.instantiate()
	
	# コンテンツシーンをインスタンス化
	var content_instance = content_scene.instantiate()
	
	# MDIウィンドウにコンテンツを追加
	var content_container = mdi_window.find_child("ContentContainer")
	if is_instance_valid(content_container):
		content_container.add_child(content_instance)
		
	# 初期化（Terminal/NetworkMap用）
	if window_type == "NetworkMap" and is_instance_valid(content_instance):
		# ネットワークマップのロード
		content_instance.load_mission(mission_manager.get_mission_data(mission_id).get("network_map_path"))
	
	# MDIウィンドウの設定
	mdi_window.title = window_title
	mdi_window.name = window_title  # 検索のためにタイトルを名前として使用
	
	# 💡 【重要な修正】Windowノードの追加方法
	# WindowノードはデフォルトでViewPortの直下に追加されるため、
	# scene tree のルートの子として `get_tree().get_root().add_child(mdi_window)`
	# または `add_child(mdi_window)` のいずれかの方法で追加されているはずです。
	# これを修正し、明示的にグローバルシーンツリーに追加します。
	
	# 修正の必要なし: Windowクラス（MDIWindow.tscn）のノードは、
	# top_levelがtrueの場合、常にViewPort直下（つまりRootSceneの兄弟）に配置されます。
	# MDIウィンドウの設計として、この動作は**正しい**ものです。

	# 接続が外れているため、MDIウィンドウをシーンツリーに再追加する
	get_tree().get_root().add_child(mdi_window) 
	
	# 💡 open_window関数内で add_child ではなく、
	# get_tree().get_root().add_child(mdi_window) 
	# または単に add_child(mdi_window) が使用されている可能性があります。

	
	# 3. 画面遷移時に解放するための辞書に登録
	open_windows[window_title] = mdi_window
	
	# 4. クローズシグナルを接続
	mdi_window.close_requested.connect(_on_window_closed.bind(window_title))

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
	## 1. 現在のUI (MissionExecutionUI) を解放
	#if is_instance_valid(current_ui_scene):
		#print("DEBUG: [RootScene] Attempting to free old UI:", current_ui_scene.name)
		## 💡 current_ui_sceneを解放
		#current_ui_scene.queue_free() 
		## 💡 解放後、参照をクリア
		#current_ui_scene = null
	#else:
		#print("DEBUG: [RootScene] No current_ui_scene to free.")
		#
	## 2. MissionSelectUIシーンをインスタンス化し、表示
	#if MISSION_SELECT_SCENE == null:
		#printerr("ERROR: MISSION_SELECT_SCENE is null. Check preload path.")
		#return
		#
	#var select_ui = MISSION_SELECT_SCENE.instantiate()
	## 💡 修正: RootSceneではなく、ui_holderの子として追加する
	#ui_holder.add_child(select_ui) 
	#current_ui_scene = select_ui
	#
	#print("Transitioning to MissionSelectUI.")
	
	navigate_to_mission_select()
