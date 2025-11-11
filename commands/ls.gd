# commands/ls.gd
extends RefCounted

var console  # terminal_ui.gd のインスタンスがセットされます
var description: String = "List directory contents."

# VFSNode は class_name でグローバルに利用可能なため、特に preload は不要。

func execute(args: Array) -> String:
	
	if not is_instance_valid(VFSCore):
		return "[ERROR] VFS Core is not available."
		
	var path_arg = ""
	if args.size() > 0:
		path_arg = args[0]
	else:
		path_arg = "." # 引数なしの場合はカレントディレクトリ

	# 【構文と引数】VFSCore.resolve_path(path, base_dir) を呼び出す
	var path_to_list = VFSCore.resolve_path(path_arg, console.current_path)

	# ターゲットが存在しない場合のチェック
	if not VFSCore.node_exists(path_to_list):
		return "ls: cannot access '" + path_to_list + "': No such file or directory"

	var target_node = VFSCore.get_node_by_path(path_to_list)

	# ターゲットがファイルの場合は、ファイル名のみを返す
	if target_node.type == VFSNode.NodeType.FILE:
		return target_node.name

	# ディレクトリの内容を取得
	# VFSCore.get_directory_contents がノード情報（DictionaryのArray）を返すことを想定
	var contents = VFSCore.get_directory_contents(path_to_list)
	
	if contents.is_empty():
		return "" # 空のディレクトリ

	var result = ""
	for item in contents:
		var name = item["name"]
		var type_value = item["type"]
		
		# 💡【修正2: NodeTypeの参照】 グローバルの VFSNode.NodeType を使用
		var prefix = ""
		if type_value == VFSNode.NodeType.DIR:
			prefix = "D : "
		elif type_value == VFSNode.NodeType.FILE:
			prefix = "F : "
		else:
			prefix = "? : "
			
		result += prefix + name + "\n"
		
	return result
