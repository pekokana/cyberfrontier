# MissionExecutionUI.gd
extends Control

# シングルトンや他のシーンへのパス
const ROOT_SCENE_PATH = "/root/RootScene"

# 💡 外部シーンファイルへのプリロード
# これらのシーンは、別途作成する必要があります (MDIのドラッグ/リサイズを担うラッパー)
const TOOL_WINDOW_SCENE = preload("res://scenes/windows/mdi_window.tscn")

# 💡 起動可能なツールの一覧を定義
# (キー:ボタンに表示する名前, 値:ツールの実体シーンパス)
const AVAILABLE_TOOLS = {
	"Terminal": "res://scenes/windows/terminal_ui.tscn",
	"NetworkMap": "res://scenes/windows/NetworkMapUI.tscn",
	"FileExplorer": "res://scenes/windows/file_explorer_ui.tscn",
	# 必要に応じてツールを追加
}
const ICON_SIZE = 32 # 💡 ツールバーに配置するアイコンの推奨サイズ (32x32)

# ==============================================================================
# UIノードの参照 (@onready)
# 提案したノード構造に基づくパスを設定
# ==============================================================================

@onready var mission_title_label = $VBoxRoot/TopBar/MissionTitle
@onready var timer_label = $VBoxRoot/TopBar/TimerLabel
@onready var exit_button = $VBoxRoot/TopBar/ExitButton
#@onready var objective_text = $VBoxRoot/WorkspaceRoot/WorkspaceSplit/InfoSidebar/ObjectivePanel/ScrollContainer/ObjectiveText

# MDI制御に必要な主要ノード
@onready var tool_launch_bar = $VBoxRoot/WorkspaceRoot/ToolLaunchBar 
@onready var mdi_canvas = $VBoxRoot/WorkspaceRoot/WorkspaceSplit/MDI_Canvas 


# ミッションデータを受け取る変数
var current_mission_id: String = ""
var mission_data: Dictionary = {}

# ==============================================================================
# 外部からの初期化
# ==============================================================================

# この関数は、RootSceneからシーンが切り替わったときに外部から呼び出されます
func initialize_mission(id: String, data: Dictionary):
	if data.is_empty():
		printerr("FATAL: Mission data is empty for ID: ", id)
		return

	current_mission_id = id
	mission_data = data
	
	print("Exec initialize_mission." + " / mission-id:" + str(current_mission_id) )
	setup_ui()
	populate_tool_launch_bar()
	
	## 💡 ミッション開始時のロジック（タイマー開始、仮想環境起動など）をここに追加
	## 💡 _ready()の最後にツリー全体を出力
	#print("====================================")
	#print("★MissoinExecutionUI - Current Scene Tree Structure:")
	#print("====================================")
	## シーンツリーのルートから処理を開始
	#Global.print_node_tree(get_tree().get_root())
	#print("====================================")

# ==============================================================================
# UIセットアップ
# ==============================================================================

func setup_ui():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 1. トップバーの更新
	var title = mission_data.get("title", "Unknown Mission")
	var difficulty = mission_data.get("difficulty", "N/A")
	mission_title_label.text = "%s - [%s]" % [title, difficulty]
	timer_label.text = "00:00:00" # 初期タイマー表示
	
	# 2. サイドバー（目標）の更新
	var description = mission_data.get("description", "目標が定義されていません。")
	var objective_full_text = "[b]目標:[/b]\n%s" % description
	#objective_text.text = objective_full_text
	
	# 3. 終了ボタンの接続
	if is_instance_valid(exit_button):
		# 古い接続を切断してから新しい接続を追加
		if exit_button.pressed.is_connected(Callable(self, "_on_exit_button_pressed")):
			exit_button.pressed.disconnect(Callable(self, "_on_exit_button_pressed"))
		exit_button.pressed.connect(_on_exit_button_pressed)


# ツール起動ドックにボタンを動的に配置
func populate_tool_launch_bar():
	# 既存の子ノードをクリア
	for child in tool_launch_bar.get_children():
		child.queue_free()
		
	for tool_name in AVAILABLE_TOOLS.keys():
		var button = Button.new()
		
		# 💡 ここでアイコンを設定する場合
		# var icon_texture = load("res://assets/icons/" + tool_name + "_32x32.png")
		# if icon_texture:
		# 	button.icon = icon_texture
		
		button.text = tool_name # アイコンがない場合はテキストを表示
		button.add_theme_font_size_override("font_size", 10) # 32x32アイコンの場合テキストは小さめ
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE) # 最小サイズをアイコンサイズに設定
		
		# ボタンが押されたらツールウィンドウを生成する関数を接続
		var tool_path = AVAILABLE_TOOLS[tool_name]
		button.pressed.connect(Callable(self, "_on_tool_launch_button_pressed").bind(tool_name, tool_path))
		
		tool_launch_bar.add_child(button)


# ==============================================================================
# イベント処理
# ==============================================================================

# ツール起動ボタンが押されたときの処理
func _on_tool_launch_button_pressed(tool_name: String, tool_scene_path: String):
	# 1. ツール本体のシーンをロード
	var tool_component_scene = load(tool_scene_path)
	if tool_component_scene == null:
		printerr("Error: Tool scene not found for: ", tool_name)
		return
		
	# 2. MDIラッパーウィンドウをインスタンス化
	var mdi_window = TOOL_WINDOW_SCENE.instantiate()
	
	# 3. MDIWindowの initialize 関数を呼び出し、タイトルとコンテンツシーンを設定
	#    この関数内でコンテンツのインスタンス化とContentContainerへの配置が行われます 
	if mdi_window.has_method("initialize"):
		mdi_window.initialize(tool_name, tool_component_scene)

	# FileExplorerの場合、初期パスを設定する
		if tool_name == "FileExplorer":
			# MDIWindowの initialize() 処理が完了し、ContentContainerに子ノードが追加されるのを
			# 次のフレームまで待機するために call_deferred を使用する
			
			# 遅延呼び出しを行う関数を Callable オブジェクトとして作成
			var set_initial_path = Callable(self, "_set_file_explorer_initial_path").bind(mdi_window)
			
			# call_deferred で次のフレームで実行する
			set_initial_path.call_deferred()


	# 4. Windowノードをシーンツリーのルート（最上位）に追加
	get_tree().get_root().add_child(mdi_window) 
	
	# 5. 初期位置を少しずらして表示 (Windowノードは画面全体に対する相対位置となる)
	mdi_window.position = Vector2(randf_range(50, 200), randf_range(50, 200))
	
	print("Launched MDI tool: ", tool_name)

# 遅延実行されるファイルエクスプローラーの初期化関数
# mdi_windowがシーンツリーに追加され、initializeが完了した後、次のフレームで実行される
func _set_file_explorer_initial_path(mdi_window: Window):
	# 1. ContentContainerの最初の子ノードが FileExplorerUI であると仮定して取得
	var tool_instance = mdi_window.get_node("ContentContainer").get_child(0)
	
	var initial_path = "/home/user" 
	
	# 2. FileExplorerUIの current_path 変数に値を設定
	if is_instance_valid(tool_instance) and tool_instance.get_script() != null and "current_path" in tool_instance:
		tool_instance.current_path = initial_path
		mdi_window.title = "File Explorer: " + initial_path
	else:
		printerr("File Explorer instance not ready or 'current_path' not found.")

# 終了ボタンが押されたときの処理
func _on_exit_button_pressed():
	print("Mission Aborted: Returning to Mission Select.")
	
	# ⚠️ ミッション中止時のリソースクリーンアップ処理をここに追加 (仮想環境停止など)
	
	var root_scene = get_node(ROOT_SCENE_PATH)
	if is_instance_valid(root_scene) and root_scene.has_method("start_mission_select_mode"):
		# RootSceneに、MissionSelectUIに戻るための関数が必要です
		root_scene.start_mission_select_mode()
	else:
		printerr("ERROR: Cannot transition back. Check RootScene for 'start_mission_select_mode'.")
