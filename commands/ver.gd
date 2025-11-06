extends RefCounted

var console  # terminal_ui.gdからセットされます

var description = "Displays the terminal program version."

func execute(args: Array) -> void:
	# バージョン情報を表示
	var program_name = "Cyber Frontier Terminal"
	var version = "v0.1"
	console._print("%s %s" % [program_name, version])
