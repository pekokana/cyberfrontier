# file_explorer_ui.gd
extends Control

# VFSへの参照はAutoLoadから取得
var vfs_core = VFSCore
var current_path: String = "/home/user"

# FSNodeスクリプトをプリロード
# VFSNode.gd がノードの型（DIR/FILE）のEnumを定義していると仮定します。
const VFS_NODE_SCRIPT = preload("res://scripts/core/VFSNode.gd")

@onready var path_label = $VBoxContainer/HBoxContainer/PathLabel
@onready var vfs_tree = $VBoxContainer/VfsTree

# MDIウィンドウを開くためのRootSceneへの参照（terminal_uiと同じ構造を仮定）
@onready var root_scene = get_tree().get_root().get_child(0)

const TEXT_EDITOR_SCENE = preload("res://scenes/windows/text_editor_ui.tscn")
const MDI_WINDOW_SCENE = preload("res://scenes/windows/mdi_window.tscn")
const PACKET_CAPTURE_SCENE = preload("res://scenes/windows/packet_capture_ui.tscn") 
const ICON_FOLDER = preload("res://assets/icons/nmap32.png")
const ICON_FILE = preload("res://assets/icons/sidebar32.png")
const ICON_PCAP = preload("res://assets/icons/pcap32.png")
# 💡 PacketCaptureツールシーンをプリロード

func _ready():
	_update_display()
	
	# Treeノードのアイテムがダブルクリックされた際のシグナルを接続
	vfs_tree.item_activated.connect(_on_vfs_tree_item_activated)

# VFSの内容をTreeに表示する
func _update_display():
	path_label.text = "Current Path: " + current_path
	vfs_tree.clear()

	var root_item = vfs_tree.create_item()
	var node = vfs_core.get_node_by_path(current_path)

	if not node:
		root_item.set_text(0, "[ERROR] Path not found.")
		return

	# 親ディレクトリへの戻る項目を追加
	if current_path != "/":
		var parent_item = vfs_tree.create_item(root_item)
		parent_item.set_text(0, "..")
		parent_item.set_icon(0, ICON_FOLDER)
		# カスタムメタデータにパスを格納
		parent_item.set_metadata(0, current_path.get_base_dir())
	
	# 子ノードをTreeに追加
	for child_name in node.children.keys():
		var child_node = node.children[child_name]
		var item = vfs_tree.create_item(root_item)
		
		item.set_text(0, child_name)
		# vfs_core.combine_paths の代わりに、文字列操作でパスを結合する
		# VFSNodeのパス結合のロジックを再現します。
		var full_path = current_path
		if not full_path.ends_with("/"):
			full_path += "/"
		full_path += child_name
		
		# set_metadataに結合後のパスを渡す
		item.set_metadata(0, full_path.simplify_path()) 
		
		# NodeTypeをVFSCoreではなく、VFS_NODE_SCRIPT経由で参照
		if child_node.type == VFS_NODE_SCRIPT.NodeType.DIR:
			item.set_icon(0, ICON_FOLDER)
		elif child_node.type == VFS_NODE_SCRIPT.NodeType.PCAP:
			item.set_icon(0, ICON_PCAP)
		# ファイル・その他のファイルの場合
		else:
			item.set_icon(0, ICON_FILE)

# Treeの項目がダブルクリックされたときの処理
func _on_vfs_tree_item_activated():
	var item = vfs_tree.get_selected()
	if not item:
		return
		
	var full_path = item.get_metadata(0)
	var node = vfs_core.get_node_by_path(full_path)
	
	if not node:
		print("Node not found: ", full_path)
		return

	# NodeTypeをVFS_NODE_SCRIPT経由で参照
	if node.type == VFS_NODE_SCRIPT.NodeType.DIR:
		# ディレクトリの場合: 移動して再描画
		current_path = full_path
		_update_display()
	elif node.type == VFS_NODE_SCRIPT.NodeType.FILE:
	# ファイルの場合: 拡張子に基づいてツールを決定
		var extension = full_path.get_extension().to_lower()
		
		# その他のファイルの場合: テキストエディタを開く
		_open_file_in_editor(full_path, node.name, node.content)
	elif node.type == VFS_NODE_SCRIPT.NodeType.PCAP:
		# 💡 PCAPファイルの場合: 専用の PacketCaptureUI で開く
		_open_pcap_in_viewer(node.path, node.name, node.content) # 新しいヘルパー関数を呼び出す
	else:
		print("Warning: Unknown node type activated: ", node.type)

# PCAPファイルを PacketCaptureUI で開くヘルパー関数
func _open_pcap_in_viewer(path: String, title: String, content: String):
	# 1. MDIラッパーウィンドウをインスタンス化
	var mdi_window = MDI_WINDOW_SCENE.instantiate()
	var window_title = title # ファイル名 (例: evidence.pcap) をタイトルにする
	
	# 2. MDIWindowの initialize 関数を呼び出し、PacketCaptureUIのPackedSceneを設定
	if mdi_window.has_method("initialize"):
		# PACKET_CAPTURE_SCENE (packet_capture_ui.tscn) を渡す
		mdi_window.initialize(window_title, PACKET_CAPTURE_SCENE) 
		
		# 3. MDIウィンドウをシーンツリーに追加
		get_tree().get_root().add_child(mdi_window)
		
		# 4. ContentContainerの子（PacketCaptureUIインスタンス）を取得し、内容を設定する
		var content_container = mdi_window.get_node("ContentContainer")
		
		if is_instance_valid(content_container) and content_container.get_child_count() > 0:
			var capture_ui = content_container.get_child(0)
			
			# 💡 PacketCaptureUI.gd の load_pcap_data 関数を呼び出す
			if capture_ui.has_method("load_pcap_data"):
				capture_ui.load_pcap_data(content)
				print("Opened PCAP viewer for: ", path)
			else:
				printerr("Error: PacketCaptureUI instance is missing 'load_pcap_data' method.")
		else:
			printerr("Error: MDI window failed to instantiate PacketCaptureUI.")
	
	# 5. 初期位置を設定
	mdi_window.position = Vector2(randf_range(50, 200), randf_range(50, 200))



# PacketCaptureツールを開くヘルパー関数
func _open_file_in_packet_capture(path: String, name: String, content: String):
	# MDI_WINDOW_SCENE と root_scene が定義されていることを前提とする
	var mdi = MDI_WINDOW_SCENE.instantiate()
	root_scene.add_child(mdi)
	
	mdi.initialize("Packet Capture: " + name, PACKET_CAPTURE_SCENE)
	mdi.size = Vector2(800, 600)
	
	var capture_ui = mdi.get_node("ContentContainer").get_child(0)
	if capture_ui.has_method("load_pcap_data"):
		capture_ui.load_pcap_data(content)


# エディタウィンドウを開くヘルパー関数
func _open_file_in_editor(path: String, title: String, content: String):
	# 1. MDIラッパーウィンドウをインスタンス化
	var mdi_window = MDI_WINDOW_SCENE.instantiate()
	
	# 2. MDIWindowの initialize 関数を呼び出し、タイトルとTextEditorのPackedSceneを設定
	if mdi_window.has_method("initialize"):
		# initialize にPackedScene（TextEditorUI.tscn）を渡す
		mdi_window.initialize(title, TEXT_EDITOR_SCENE) 
		
		# 3. MDIウィンドウをシーンツリーのルートに追加 (MissionExecutionUIの起動ロジックに合わせる)
		# Windowノードは親のCanvasではなく、ルートに追加することでトップレベルウィンドウとして機能します
		get_tree().get_root().add_child(mdi_window)
		
		# 4. ContentContainerの子（TextEditorUIインスタンス）を取得し、内容を設定する
		# mdi_window.initialize()内でインスタンス化が完了しているため、すぐにアクセス可能です。
		
		# ContentContainerノードへのパスを直接指定
		var content_container = mdi_window.get_node("ContentContainer")
		
		if is_instance_valid(content_container) and content_container.get_child_count() > 0:
			var editor_ui = content_container.get_child(0)
			
			if editor_ui.has_method("load_content"):
				editor_ui.load_content(path, content) # ファイル内容のロード
			
			# 5. 初期位置とサイズを設定 (複数のウィンドウが重ならないようにランダムに設定)
			mdi_window.position = Vector2i(randf_range(50, 200), randf_range(50, 200))
			mdi_window.size = Vector2i(400, 300)
			
		else:
			printerr("Error: Text Editor UI instance not found inside MDIWindow.")
			mdi_window.queue_free()
	else:
		printerr("Error: MDIWindow does not have 'initialize' method.")
