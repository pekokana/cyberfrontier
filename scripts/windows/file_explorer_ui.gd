extends Control

# VFSへの参照はAutoLoadから取得
# VFSCoreはプロジェクト設定でAutoLoadとして登録されている前提
var vfs_core = VFSCore
var current_path: String = "/home/user"

# FSNodeスクリプトをプリロード
# VFSNode.gd がノードの型（DIR/FILE/PCAP）のEnumを定義していると仮定します。
const VFS_NODE_SCRIPT = preload("res://scripts/core/VFSNode.gd")

@onready var path_label = $VBoxContainer/HBoxContainer/PathLabel
@onready var vfs_tree = $VBoxContainer/VfsTree

# MDIウィンドウを開くためのRootSceneへの参照（TerminalUIと同じ構造を仮定）
# MDIWindowをルートに追加するため、get_tree().get_root()で直接追加します
# @onready var root_scene = get_tree().get_root().get_child(0) # 冗長なので削除

const TEXT_EDITOR_SCENE = preload("res://scenes/windows/text_editor_ui.tscn")
const MDI_WINDOW_SCENE = preload("res://scenes/windows/mdi_window.tscn")
const PACKET_CAPTURE_SCENE = preload("res://scenes/windows/packet_capture_ui.tscn")
const ICON_FOLDER = preload("res://assets/icons/nmap32.png")
const ICON_FILE = preload("res://assets/icons/sidebar32.png")
const ICON_PCAP = preload("res://assets/icons/pcap32.png")

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
	#if current_path != "/":
		#var parent_item = vfs_tree.create_item(root_item)
		#parent_item.set_text(0, "..")
		#parent_item.set_icon(0, ICON_FOLDER)
		## カスタムメタデータにパスを格納
		#parent_item.set_metadata(0, current_path.get_base_dir())

# 親ディレクトリへの戻る項目を追加
	var user_root_path = vfs_core.USER_DIR_PATH # /home/user を参照 

	# 【修正箇所】現在のパスがユーザーのローカルルート (/home/user) ではない場合にのみ ".." を表示する
	if current_path.simplify_path() != user_root_path.simplify_path():
		var parent_item = vfs_tree.create_item(root_item)
		parent_item.set_text(0, "..")
		parent_item.set_icon(0, ICON_FOLDER)
		# カスタムメタデータにパスを格納
		# simplify_path() は末尾のスラッシュなどを正規化するために使用
		parent_item.set_metadata(0, current_path.get_base_dir().simplify_path())
	
	
	# 子ノードをTreeに追加
	for child_name in node.children.keys():

		# 【VFS内部パスのフィルタリング】
		# ルートディレクトリ ("/") をリスト表示する際、WebサーバーのVFSマウントポイント
		# である "vfs" ディレクトリをスキップする。
		if current_path == "/" and child_name == "vfs":
			continue

		var child_node = node.children[child_name]
		var item = vfs_tree.create_item(root_item)
		
		item.set_text(0, child_name)
		# パスの結合
		var full_path = current_path
		if not full_path.ends_with("/"):
			full_path += "/"
		full_path += child_name
		
		# set_metadataに結合後のパスを渡す
		item.set_metadata(0, full_path.simplify_path())
		
		# NodeTypeをVFS_NODE_SCRIPT経由で参照し、アイコンを設定
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
	# ファイルの場合: テキストエディタを開く
	# 拡張子チェックのロジックは削除し、FILEタイプはすべてエディタで開く
		_open_file_in_editor(full_path, node.name, node.content)
	elif node.type == VFS_NODE_SCRIPT.NodeType.PCAP:
		# PCAPファイルの場合: 専用の PacketCaptureUI で開く
		_open_pcap_in_viewer(node.path, node.name, node.content)
	else:
		print("Warning: Unknown node type activated: ", node.type)

# PCAPファイルを PacketCaptureUI で開くヘルパー関数
func _open_pcap_in_viewer(path: String, title: String, content: String):
	# 1. MDIラッパーウィンドウをインスタンス化
	var mdi_window = MDI_WINDOW_SCENE.instantiate()
	var window_title = "[PCAP] " + title # ファイル名 (例: evidence.pcap) をタイトルにする
	
	# 2. MDIWindowの initialize 関数を呼び出し、PacketCaptureUIのPackedSceneを設定
	if mdi_window.has_method("initialize"):
		# PACKET_CAPTURE_SCENE (packet_capture_ui.tscn) を渡す
		mdi_window.initialize(window_title, PACKET_CAPTURE_SCENE)
		
		# 3. MDIウィンドウをシーンツリーに追加 (トップレベルウィンドウとして機能)
		get_tree().get_root().add_child(mdi_window)
		
		# 4. ContentContainerの子（PacketCaptureUIインスタンス）を取得し、内容を設定する
		var content_container = mdi_window.get_node("ContentContainer")
		
		if is_instance_valid(content_container) and content_container.get_child_count() > 0:
			var capture_ui = content_container.get_child(0)
			
			# PacketCaptureUI.gd の load_pcap_data 関数を呼び出す
			if capture_ui.has_method("load_pcap_data"):
				capture_ui.load_pcap_data(content)
				print("Opened PCAP viewer for: ", path)
			else:
				printerr("Error: PacketCaptureUI instance is missing 'load_pcap_data' method.")
		else:
			printerr("Error: MDI window failed to instantiate PacketCaptureUI.")
	
	# 5. 初期位置を設定
	mdi_window.position = Vector2(randf_range(50, 200), randf_range(50, 200))
	mdi_window.size = Vector2(800, 600)

# エディタウィンドウを開くヘルパー関数
func _open_file_in_editor(path: String, title: String, content: String):
	# 1. MDIラッパーウィンドウをインスタンス化
	var mdi_window = MDI_WINDOW_SCENE.instantiate()
	
	# 2. MDIWindowの initialize 関数を呼び出し、タイトルとTextEditorのPackedSceneを設定
	if mdi_window.has_method("initialize"):
		# initialize にPackedScene（TextEditorUI.tscn）を渡す
		mdi_window.initialize(title, TEXT_EDITOR_SCENE)
		
		# 3. MDIウィンドウをシーンツリーのルートに追加
		get_tree().get_root().add_child(mdi_window)
		
		# 4. ContentContainerの子（TextEditorUIインスタンス）を取得し、内容を設定する
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
