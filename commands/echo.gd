extends RefCounted

var console  # terminal_ui.gd のインスタンスがセットされます

var description = "Echoes the input arguments back to the terminal."

func execute(args: Array) -> String:
	# 配列が空かどうかは size プロパティで判定
	if args.size() == 0:
		return "Usage: echo [text]"

	# 配列を文字列に結合する場合は join メソッドではなく " ".join(args) 形式
	return " ".join(args)
