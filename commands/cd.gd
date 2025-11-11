# commands/cd.gd

extends RefCounted

var console      # terminal_ui.gd からセットされます
var description: String = "Change the current working directory."

func execute(args: Array) -> String:
	
	if not is_instance_valid(VFSCore):
		return "[ERROR] VFS Core is not available."
		
	var path_arg = "/" # 引数がない場合はルートへ移動
	if args.size() > 0:
		path_arg = args[0]
	
	# 1. VFSCoreの共通ロジックを使って、移動先の絶対パスを解決する
	var resolved_path = VFSCore.resolve_path(path_arg, console.current_path)
	
	# 2. 移動先のノードが存在するかチェックする
	if not VFSCore.node_exists(resolved_path):
		return "cd: no such file or directory: %s" % resolved_path

	# 3. ノードがディレクトリであることをチェックする
	var target_node = VFSCore.get_node_by_path(resolved_path)
	
	# 💡 VFSNode.NodeType.DIR を使用してディレクトリか確認
	if target_node.type != VFSNode.NodeType.DIR: 
		return "cd: not a directory: %s" % resolved_path
		
	# 4. 成功: terminal_uiのcurrent_pathを更新する
	console.current_path = resolved_path
	
	# 成功した移動先のパスを出力として返す
	# この文字列がターミナルに出力されます。
	return resolved_path
