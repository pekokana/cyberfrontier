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
const ICON_FOLDER = preload("res://assets/icons/nmap32.png")
const ICON_FILE = preload("res://assets/icons/sidebar32.png")

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
		# ファイルの場合: エディタウィンドウを開く
		_open_file_in_editor(full_path, node.name, node.content)
	
# エディタウィンドウを開くヘルパー関数
func _open_file_in_editor(path: String, title: String, content: String):
	# RootSceneのopen_window関数を呼び出してエディタウィンドウを開く
	if root_scene.has_method("open_window"):
		# 1. MDIウィンドウをインスタンス化
		var mdi_window = MDI_WINDOW_SCENE.instantiate()
		mdi_window.title = title
		
		# 2. エディタUIをインスタンス化し、MDIウィンドウに組み込む
		var editor_ui = TEXT_EDITOR_SCENE.instantiate()
		
		# 3. エディタにファイル内容をセット
		if editor_ui.has_method("load_content"):
			editor_ui.load_content(path, content)
		
		# 4. RootSceneのopen_window関数を通じてMDIウィンドウを開く
		root_scene.open_window(title, editor_ui)
