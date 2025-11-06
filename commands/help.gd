extends RefCounted

var console
var description: String = "Displays the list of available commands with descriptions."

func execute(_args: Array) -> String:
	var result = "Available commands:\n"
	var cmd_list = console.commands.keys()
	cmd_list.sort()
	
	# 各コマンドにdescription変数が定義されている場合に、コマンド概要として表示する
	var lines = []
	for cmd_name in cmd_list:
		var cmd = console.commands[cmd_name]
		var dsc = ""
		# descriptionが定義されていれば追加
		if "description" in cmd:
			dsc = ": " + str(cmd.description)
		result += cmd_name + dsc + "\n"
		#lines.append("%s: %s" % [cmd_name, dsc])
	
	#return "Available commands:\n" + "\n".join(cmd_list)
	#return lines.join("\n")
	return result
