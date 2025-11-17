## VFSCore.gd (Project Settings -> AutoLoad で設定)
extends Node
#
#const VFSNode = preload("VFSNode.gd")
const VFSNode = preload("res://scripts/core/VFSNode.gd")
const ROOT_PATH = "/home/user"
#
## ファイルシステム全体を保持するルートノード
var root_node: VFSNode

## --- 初期化とセットアップ ---

func _ready():
	## アプリ起動時にVFSを初期化する
	initialize_vfs()
	# 成功確認のための単純な出力のみを残す
	print("VFSCore: --- MINIMAL AutoLoad _ready() called. VFSCore Loaded! ---")
#
func initialize_vfs():
	# /home/user ディレクトリ構造を作成
	#root_node = VFSNode.new("user", VFSNode.NodeType.DIR, ROOT_PATH)
	root_node = VFSNode.new("user", VFSNode.NodeType.DIR, ROOT_PATH)
#
func load_mission_setup(initial_files: Array):
	# VFSをリセットし、新しいミッションのファイルをロード
	initialize_vfs()
	for file_data in initial_files:
		_create_node_from_path(file_data.path, file_data.type, file_data.content)
	print("VFS: Mission files loaded successfully.")

# --- 内部ヘルパー関数 ---
# パスを受け取り、指定されたノードを検索する
func get_node_by_path(path: String) -> VFSNode:
	var current_node = root_node
	# /home/user から始まるパスを想定し、分割
	var parts = path.split("/")
	
	# 最初の3要素 (空, "home", "user") はスキップ
	for i in range(3, parts.size()):
		print("  get_node_by_path：" + str(i) + " > " + parts[i])
		var part_name = parts[i]
		if part_name == "" or part_name == ".":
			continue
		if part_name == "..":
			# 親ディレクトリへの移動 (実装は簡略化のため省略しても可)
			# ここではシンプルに、.. の処理は一旦スキップするかエラーとする
			return null # 複雑化を避けるため
		
		if current_node.type == VFSNode.NodeType.DIR and current_node.children.has(part_name):
			current_node = current_node.children[part_name]
		else:
			return null # ノードが見つからない

	return current_node

# パスに基づきノード（ファイルまたはディレクトリ）を作成
func _create_node_from_path(full_path: String, node_type_str: String, content: String = ""):
	# ノード名と親パスを取得
	var node_name = full_path.get_file()
	var parent_path = full_path.get_base_dir()
	
	# ... (親ディレクトリの存在チェックと作成ロジックは省略) ...
	var parent_node = get_node_by_path(parent_path)
	
	if not parent_node:
		# 親ノードの作成ロジックは維持
		if not create_dir(parent_path):
			print("VFS Error: Failed to create parent directory: " + parent_path)
			return
		parent_node = get_node_by_path(parent_path) # 作成後に再取得
	
	if parent_node.type != VFSNode.NodeType.DIR:
		print("VFS Error: Parent node is not a directory: " + parent_path)
		return
		
	# 3. ファイルノードを作成
	var type_enum: int
	match node_type_str.to_lower(): # 💡 ここでタイプを正確にマッピングします
		"dir":
			type_enum = VFSNode.NodeType.DIR
		"pcap":
			type_enum = VFSNode.NodeType.PCAP
		_: # "file" やその他の不明なタイプ
			type_enum = VFSNode.NodeType.FILE
	
	var new_node = VFSNode.new(node_name, type_enum, full_path, content)
	parent_node.children[node_name] = new_node
	print("VFS: Created node: ", full_path, " Type: ", node_type_str)


# --- 外部API (コマンドロジック層が利用) ---
# ファイルの内容を読み取る (cat, grepが利用)
func read_file(path: String) -> String:
	#return "Error: File or directory not found."

	var node = get_node_by_path(path)
	if not node:
		return "Error: File or directory not found."
	if node.type == VFSNode.NodeType.DIR:
		return "Error: Cannot read a directory."
		
	# バイナリファイルなども想定されるが、ここではStringとして返す
	return node.content

## ディレクトリの内容を取得する (lsが利用)
func get_directory_contents(path: String) -> Array:
	#return ["Error: Directory not found."]
	var node = get_node_by_path(path)
	if not node:
		return ["Error: Directory not found."]
	if node.type == VFSNode.NodeType.FILE:
		return ["Error: Cannot list contents of a file."]
		
	var contents = []
	for name in node.children.keys():
		# ls コマンド用に、ファイル名とタイプ（ディレクトリかファイルか）の情報を返す
		contents.append({"name": name, "type": node.children[name].type})
	return contents

# ノードが存在するかチェックする (cdなどが利用)
func node_exists(path: String) -> bool:
	return get_node_by_path(path) != null

# 外部API: ディレクトリを作成する
func create_dir(path: String) -> bool:
	var parent_path = path.get_base_dir()
	var dir_name = path.get_file()
	
	var parent_node = get_node_by_path(parent_path)
	
	if not parent_node or parent_node.type != VFSNode.NodeType.DIR:
		# 親ディレクトリがなければ、まず親ディレクトリを作成する
		if create_dir(parent_path):
			parent_node = get_node_by_path(parent_path)
		else:
			return false # 親の作成も失敗
			
	if parent_node.children.has(dir_name):
		return true # 既に存在する
		
	# 新しいディレクトリノードを作成
	#var new_dir_node = VFSNode.new(dir_name, VFSNode.NodeType.DIR, path)
	var new_dir_node = VFSNode.new(dir_name, VFSNode.NodeType.DIR, path)
	parent_node.children[dir_name] = new_dir_node
	return true

# 相対パスと絶対パスを解決し、整形された絶対パスを返す
func resolve_path(path: String, base_dir: String) -> String:
	# 1. 絶対パスの処理
	if path.begins_with("/"):
		return path.simplify_path()
	
	# 2. 特殊パス ( . と .. )
	if path == ".":
		return base_dir
	
	if path == "..":
		var parts = base_dir.split("/")
		
		# 💡【修正】back() の代わりに [-1] を使用
		# 末尾の空文字列（例: /home/user/ の最後の /）を削除
		if parts.size() > 0 and parts[-1].is_empty():
			# 💡【修正】pop_back() の代わりに remove_at(size - 1) を使用
			parts.remove_at(parts.size() - 1)
		
		# 親ディレクトリを削除
		if parts.size() > 0:
			# 💡【修正】pop_back() の代わりに remove_at(size - 1) を使用
			parts.remove_at(parts.size() - 1)
		
		var parent_path = "/".join(parts)
		
		## ルートディレクトリまで戻った場合 ('') -> '/' にする
		return "/" if parent_path.is_empty() else parent_path.simplify_path()

	# 3. 相対パスの結合
	var resolved_path = base_dir
	if not resolved_path.ends_with("/"):
		resolved_path += "/"
		
	resolved_path += path
	
	return resolved_path.simplify_path()

# ファイルの内容を保存する関数
# 成功したら true、失敗したら false を返す
func save_file_content(path: String, content: String) -> bool:
	var node = get_node_by_path(path)
	
	# ノードが存在するか、かつファイルタイプであるかを確認
	if not node:
		printerr("VFS Save Error: Node not found at path: ", path)
		return false
	
	# 💡 NodeTypeへの参照は VFSNode.gd の定数を使用
	# VFSNode.gd が正しくロードされていることを確認してください。
	var VFS_NODE_SCRIPT = preload("res://scripts/core/VFSNode.gd") # 実際のパスに修正
	
	if node.type != VFS_NODE_SCRIPT.NodeType.FILE:
		printerr("VFS Save Error: Path is not a file: ", path)
		return false
	
	# 内容を更新
	node.content = content
	
	# 💡 ここで、VFSが永続化される場合は、永続化ロジック（例: JSONへの書き出し）を追加
	return true


# 💡 追加: パスを指定してファイルの内容を更新する
func update_file_content(path: String, new_content: String) -> bool:
	var node = get_node_by_path(path)
	
	# 💡 ファイルタイプ（FILEまたはPCAP）であることを確認
	if node and (node.type == VFSNode.NodeType.FILE or node.type == VFSNode.NodeType.PCAP):
		node.content = new_content
		print("VFS: Content updated for file: " + path)
		return true
	
	printerr("VFS ERROR: Cannot update content. Path is not a file or does not exist or wrong type: " + path)
	return false

# VFSを完全にクリアし、ルートノードを再作成する
func reset_vfs():
	# initialize_vfs() は root_node = VFSNode.new(...) を実行し、VFSを初期状態に戻す想定
	initialize_vfs()
	print("VFS: Fully reset to initial state.")
