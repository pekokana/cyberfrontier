# commands/pwd.gd

extends RefCounted

var console      # terminal_ui.gd からセットされます
var description: String = "Print name of current working directory."

func execute(args: Array) -> String:
	# console.current_path には絶対パスが入っているため、それをそのまま返す
	return console.current_path
