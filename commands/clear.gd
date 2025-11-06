extends RefCounted

var console  # terminal_ui.gdからセットされます

var description = "Clears the terminal screen."

func execute(args: Array) -> void:
	# 出力をすべてクリア
	console.output_box.text = ""
