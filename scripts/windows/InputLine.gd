# InputLine.gd
# LineEditノードにアタッチ
extends LineEdit

# メインのターミナルインスタンスへの参照（_readyで設定される）
@onready var console = get_parent().get_parent()
# ^ TerminalUI ノードへの参照を取得します (VBoxContainer -> Control)

# Controlノードの入力処理（_gui_input）をオーバーライド
func _gui_input(event: InputEvent) -> void:
	# キーボードイベントかつ押された瞬間のみをチェック
	if event is InputEventKey and event.pressed:
		var handled = false
		
		if event.keycode == KEY_UP:
			if console.command_history.size() > 0:
				console.history_index = maxi(console.history_index - 1, 0)
				text = console.command_history[console.history_index]
				# 修正: Godot 4では caret_column を使用
				caret_column = text.length() 
				handled = true
				
		elif event.keycode == KEY_DOWN:
			if console.command_history.size() > 0:
				console.history_index = mini(console.history_index + 1, console.command_history.size())
				if console.history_index < console.command_history.size():
					text = console.command_history[console.history_index]
				else:
					text = ""
				# 修正: Godot 4では caret_column を使用
				caret_column = text.length() 
				handled = true
				
		elif event.keycode == KEY_TAB:
			var current = text.strip_edges()
			if current != "":
				var matches = []
				for cmd_name in console.commands.keys():
					if cmd_name.begins_with(current):
						matches.append(cmd_name)
				if matches.size() == 1:
					text = matches[0]
					# 修正: Godot 4では caret_column を使用
					caret_column = text.length() 
					handled = true
			else:
				handled = true # 空欄でのTABもここで消費する

		if handled:
			# 履歴操作や補完が行われたら、イベントを消費してLineEditのデフォルト処理を停止
			get_viewport().set_input_as_handled() 
			return
	
	# 上記で処理されなかったイベントは、
	# 何も返さないことで、LineEditが自動的にデフォルトの処理（文字入力など）を行います。
	# super._gui_input(event) は削除済み。
