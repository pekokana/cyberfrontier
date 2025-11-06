extends Node2D

var mdi_window_scene = preload("res://mdi_window.tscn")
var terminal_scene = preload("res://terminal_ui.tscn")
var networkmap_scene = preload("res://NetworkMapUI.tscn")
var sidebar_scene = preload("res://Sidebar.tscn")
var mission_select_scene = preload("res://MissionSelectUI.tscn")

# 開いているウィンドウを管理する辞書（重複防止用）
var open_windows: Dictionary = {}

# MDIウィンドウを配置するノードへの参照
@onready var mdi_area = $UI_Layer/MainUIContainer/MainHBox/MDI_Area 
# アニメーションを制御するノード (SidebarContainerの子として追加するのがベスト)
@onready var animator = $UI_Layer/MainUIContainer/AnimationPlayer # RootSceneにAnimationPlayerノードを追加

@onready var sidebar_toggle = $UI_Layer/SidebarToggle
var sidebar_instance: Control = null # <--- Sidebarインスタンスを保持する変数

# サイドバーの幅とアニメーション時間をここで定数として定義し、sidebar.gdと同期させる
const SIDEBAR_WIDTH = Global.SIDEBAR_WIDTH
const TWEEN_DURATION = Global.TWEEN_DURATION

var sidebar_expanded: bool = false
const COLLAPSED_WIDTH = 20.0
const EXPANDED_WIDTH = 150.0 # 展開後の幅

func _ready():

	# 起動時にターミナルウィンドウを開く
	#open_window("Terminal", terminal_scene)

	# 💡 追記: 起動時にマップウィンドウを開く (MDIウィンドウとして)
	# ターミナルと位置をずらして、ウィンドウが重ならないようにする
	#open_window("Network Map", networkmap_scene, Vector2(600, 100))

	# 💡 追記: 起動時にミッション選択画面を開く
	open_mission_select_ui()

	### サイドバーを表示する
	#var sidebar_ui = sidebar_scene.instantiate()
	#$UI_Layer.add_child(sidebar_ui) 
	#sidebar_instance = sidebar_ui
	
	#set_mission_mode("initial")

# ミッション選択UIを開く関数
func open_mission_select_ui():
	var select_ui = mission_select_scene.instantiate()
	$UI_Layer.add_child(select_ui) 
	# select_ui.set_anchors_preset(Control.PRESET_FULL_RECT) # MissionSelectUI.gdで設定済み

# ミッション開始関数
func start_mission(mission_id: String):
	# 1. MissionManagerからミッションデータを取得
	var mission_data = MissionManager.get_mission_data(mission_id)
	
	if mission_data.is_empty():
		print("Error: Failed to load data for mission: ", mission_id)
		return

	# 2. 既存の開いているウィンドウを全て閉じる (オプション)
	for id in open_windows.keys():
		if is_instance_valid(open_windows[id]):
			open_windows[id].queue_free()
	open_windows.clear()
	
	# 3. 必要な初期ウィンドウを開く (例: Terminalは必須)
	open_window("Terminal", terminal_scene)
	
	# 4. サイドバーの機能やネットワークマップの初期ロード処理（今後の実装）
	# set_mission_mode(mission_id)
	
	# 5. UIにミッションタイトルや目標を表示する処理（今後の実装）
	print("Mission Started: ", mission_data.get("title"))

# 💡 ウィンドウを開く汎用関数
func open_window(window_id: String, content_scene: PackedScene, initial_position: Vector2 = Vector2(50, 50)):
	if open_windows.has(window_id) and is_instance_valid(open_windows[window_id]):
		# すでに開いている場合は最前面に移動して終了
		open_windows[window_id].grab_focus()
		return
	
	var mdi_window = mdi_window_scene.instantiate()
	#self.add_child(mdi_window) # RootSceneの子として追加
	# UI_Layerの子供として追加する
	$UI_Layer.add_child(mdi_window)
	
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

# 

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
