# commands/cat.gd
extends RefCounted

var console
var description: String = "Concatenate and print files (VFS)."

func execute(args: Array) -> String:
	if args.size() != 1:
		return "Usage: cat <file>"

	var file_path = _resolve_path(args[0])
	
	# VFSコアからファイル内容を取得
	var content = console.vfs_core.read_file(file_path)

	# VFSコアがエラーを文字列で返すと仮定
	if content.begins_with("Error:"):
		return "cat: " + args[0] + ": No such file or directory"
		
	return content

# 簡易的なパス解決（ls.gdと同じ）
func _resolve_path(path_arg: String) -> String:
	if path_arg.begins_with("/"):
		return path_arg # 絶対パス
	
	# 相対パスを解決
	var combined = console.current_path.path_join(path_arg)
	return combined
