extends Control

@onready var input_line = $VBoxContainer/InputLine
@onready var output_box = $VBoxContainer/ScrollContainer/OutputBox
@onready var scroll = $VBoxContainer/ScrollContainer
@onready var scrollbar = scroll.get_v_scroll_bar()

# 出力タイプを区別
enum OutputType {INPUT, SYSTEM}

var command_history: Array[String] = []
var history_index: int = -1
var commands = {} # "help" → インスタンス

# 💡 デバッグ用変数：前回のフォーカスノードを保持
var last_focused_node: Object = null

# MDI子側からアクセスするためのブリッジ用
@onready var root_scene = get_tree().get_root().get_child(0) # RootSceneノードにアクセス

func handle_scrollbar_changed():
	pass

func _ready():
	#input_line.connect("text_submitted", Callable(self, "_on_command_entered"))
	_register_builtin_commands()
	_load_external_commands()
	
	# TextEditの内容が変わったらスクロール関数を呼ぶように接続
	#output_box.text_changed.connect(_on_output_box_text_changed)
	
	# 起動ときにターミナル名とバージョンを表示
	_print("Cyber Frontier Terminal v0.1")
	_print("Type 'help' for commands.\n")

	# ルートノード(Terminal_ui)にもフォーカスを要求する
	#self.grab_focus()

	# InputLineにもフォーカスを要求する（ここは入力開始に必要）
	input_line.grab_focus()

## フォーカス追跡関数
func _process(_delta):
	var current_focused_node = get_viewport().gui_get_focus_owner()
	
	# フォーカスを持つノードが変化した、かつ null でない場合に実行
	if current_focused_node != last_focused_node and current_focused_node != null:
		print("--- 焦点移動 ---")
		# ノード名とその型を出力
		print("New Focus: ", current_focused_node.name, " (Type: ", current_focused_node.get_class(), ")")
		print("--------------")
		last_focused_node = current_focused_node
	
	# フォーカスが完全に外れた場合（ウィンドウ全体など）も記録
	if current_focused_node == null and last_focused_node != null:
		print("--- 焦点喪失 ---")
		print("Focus lost to application/viewport.")
		print("--------------")
		last_focused_node = null

func open_map_window():
	#root_scene.open_window("Network Map", preload("res://network_map_ui.tscn"))
	pass

func _register_builtin_commands():
	_register_command("help", preload("res://commands/help.gd").new())
	_register_command("scan", preload("res://commands/scan.gd").new())
	_register_command("echo", preload("res://commands/echo.gd").new())
	_register_command("ver", preload("res://commands/ver.gd").new())
	_register_command("clear", preload("res://commands/clear.gd").new())
	_register_command("exit", preload("res://commands/exit.gd").new())
	

func _load_external_commands():
	var dir = DirAccess.open("res://Console/commands/")
	if dir:
		for file_name in dir.get_files():
			if file_name.ends_with(".gd"):
				var path = "res://Console/commands/%s" % file_name
				var cmd_name = file_name.replace(".gd", "")
				print(path + " / " + cmd_name)
				if not commands.has(cmd_name):
					var instance = load(path).new()
					_register_command(cmd_name, instance)

func _register_command(cmd_name: String, instance: Object):
	if instance.has_method("execute") or instance.has_method("execute_async"):
		commands[cmd_name] = instance
		instance.console = self

func _on_command_entered(text: String):
	if text.strip_edges() == "":
		return
	_print(text, OutputType.INPUT)
	command_history.append(text)
	history_index = command_history.size()
	input_line.clear()

	var parts = text.split(" ", false)
	var cmd_name = parts[0]
	var args = parts.slice(1, parts.size())

	if commands.has(cmd_name):
		var cmd = commands[cmd_name]
		if cmd.has_method("execute_async"):
			await cmd.execute_async(args)
			input_line.grab_focus()
		else:
			var result = cmd.execute(args)
			if result != null:
				_print(str(result))
	else:
		_print("[ERROR] Unknown command: " + cmd_name)

	#_smooth_scroll_to_bottom()
	
	# 重要なポイント：grab_focus()を次のフレームに遅延させる
	# これにより、LineEditのデフォルトのフォーカス喪失処理の後に実行される
	#await get_tree().process_frame
	#input_line.grab_focus()

func _print(message: String, type: OutputType = OutputType.SYSTEM):
	var prefix = ""
	
	match type:
		OutputType.INPUT:
			prefix = "> "
		OutputType.SYSTEM:
			prefix = ""
	output_box.text += prefix + message + "\n"
	
	# 💡 【修正】@onreadyで取得したScrollContainer内のVScrollBarを利用する
	# スクロールバーが計算を完了するのを待つため、set_deferredを使用するのが最も確実です。
	# TextEditにテキストが追加された後、次のフレームでレイアウトとスクロールバーの値が更新されます。
	
	# 1. VScrollBarノードの最大スクロール値を取得
	var max_scroll_value = scrollbar.get_max() 
	
	# 2. VScrollBarの値を最大値に設定し、最下部までスクロール（遅延実行）
	# Godot 3.xの場合: set_value()
	# Godot 4.xの場合: set_value() または set_scroll_vertical()
	scrollbar.set_deferred("value", max_scroll_value)
	
	# 💡 補足: set_deferredを使わず、現在のフレームで強制的に値を設定したい場合は、
	# output_boxのlayout_update_scrollbar()などを呼んでから set_value() を試す方法もありますが、
	# set_deferredが最もシンプルで安全な解決策です。
	
	input_line.grab_focus()


func _input(event):
	# InputLineがフォーカスを持っている、かつキーボードイベントの場合
	if input_line.has_focus() and event is InputEventKey and event.pressed:
		
		# 履歴操作 (UP/DOWN) を追加
		if event.keycode == KEY_UP:
			if command_history.size() > 0:
				# 履歴を遡る
				history_index = max(history_index - 1, 0)
				input_line.text = command_history[history_index]
				input_line.caret_column = input_line.text.length() # Godot 4: caret_column
			
			# イベントを消費して競合を回避
			get_viewport().set_input_as_handled() 
			
		elif event.keycode == KEY_DOWN:
			if command_history.size() > 0:
				# 履歴を進める (サイズまで進むと空欄になる)
				history_index = min(history_index + 1, command_history.size())
				if history_index < command_history.size():
					input_line.text = command_history[history_index]
				else:
					input_line.text = "" # 最新の入力
				input_line.caret_column = input_line.text.length() # Godot 4: caret_column
			
			# イベントを消費して競合を回避
			get_viewport().set_input_as_handled()

		elif event.keycode == KEY_TAB:
			var current = input_line.text.strip_edges()
			
			# Tabキーが押されたら、そのイベントを消費してフォーカス移動を防ぐ
			get_viewport().set_input_as_handled()
			
			if current == "":
				return

			var matches = []
			for cmd_name in commands.keys():
				if cmd_name.begins_with(current):
					matches.append(cmd_name)
			
			if matches.size() == 1:
				input_line.text = matches[0]
				input_line.caret_column = input_line.text.length()
			
		# Enterキーの処理（連続入力のために必須）
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_command_entered(input_line.text)
			
			# Enterキーのデフォルト動作（フォーカス喪失）を停止
			get_viewport().set_input_as_handled()
			
			# フォーカスを戻す（次のフレームへの遅延は不要）
			input_line.grab_focus()
