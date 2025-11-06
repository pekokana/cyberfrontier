extends RefCounted

var console  # TerminalUI からセットされます
var description: String = "Exit the terminal."

func execute(args: Array) -> String:
	console._print("Exiting terminal...")
	# アプリを終了
	#console.get_tree().quit()
	return "Terminal closed."
