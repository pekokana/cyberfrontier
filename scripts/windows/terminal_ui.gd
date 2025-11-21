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

# VFS対応：現在の作業ディレクトリを保持
var current_path: String = "/home/user"

# ターミナルプロンプトの接頭辞を保持
var prompt_prefix: String = "user@cyb-pc:/$ "

# デバッグ用変数：前回のフォーカスノードを保持
var last_focused_node: Object = null

# MDI子側からアクセスするためのブリッジ用
@onready var root_scene = get_tree().get_root().get_child(0) # RootSceneノードにアクセス

# VFSコアへの参照を保持する変数
var vfs_core

func handle_scrollbar_changed():
	pass

func _ready():
	# VFSCore AutoLoadへの参照を取得
	# VFSCoreがAutoLoad名として登録されていると仮定し、直接アクセスします。
	vfs_core = VFSCore

	## _ready()の最後にツリー全体を出力
	#print("====================================")
	#print("@@ MDI Window Scene Tree Structure:")
	#print("====================================")
	## シーンツリーのルートから処理を開始
	#Global.print_node_tree(get_tree().get_root())
	#print("====================================")


	# VFSCoreが正しく初期化されているか確認
	if not is_instance_valid(vfs_core):
		_print("[FATAL ERROR] VFSCore is not loaded or AutoLoad setup is incorrect.", OutputType.SYSTEM)
		return

	#_print("[INFO] VFSCore successfully accessed by terminal_ui.", OutputType.SYSTEM) # <-- 成功確認メッセージの追加推奨

	_register_builtin_commands()
	_load_external_commands()
	
	# TextEditの内容が変わったらスクロール関数を呼ぶように接続
	#output_box.text_changed.connect(_on_output_box_text_changed)
	
	# 起動ときにターミナル名とバージョンを表示
	_print("Cyber Frontier Terminal v0.1")
	_print("Type 'help' for commands.\n")
	_print("") # 空行でプロンプトと区切り

	# 初回プロンプト表示
	_update_prompt()

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
	_register_command("pscan", preload("res://commands/pscan.gd").new())
	_register_command("echo", preload("res://commands/echo.gd").new())
	_register_command("ver", preload("res://commands/ver.gd").new())
	_register_command("clear", preload("res://commands/clear.gd").new())
	_register_command("exit", preload("res://commands/exit.gd").new())
	
	# VFSコマンドの追加
	_register_command("ls", preload("res://commands/ls.gd").new())
	_register_command("cat", preload("res://commands/cat.gd").new())
	_register_command("cd", preload("res://commands/cd.gd").new())
	_register_command("pwd", preload("res://commands/pwd.gd").new())
	
	# serviceコマンドの追加
	_register_command("ftp", preload("res://commands/ftp.gd").new())

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

	# trimmed_text を定義
	var trimmed_text = text.strip_edges()
	
	if trimmed_text == "":
		# 空コマンドの場合もプロンプトを再表示
		_update_prompt()
		return

	# 接続中のFTPセッションがある場合の処理
	var ftp_session = commands.get("ftp")
	if ftp_session and not ftp_session.current_session.is_empty():
		# 接続中の場合は、入力全体をFTPセッションに渡す
		var output = ftp_session._handle_session_input(trimmed_text)
		
		# _print_output -> _print に変更
		_print(prompt_prefix + trimmed_text, OutputType.INPUT) # 入力を表示
		_print(output, OutputType.SYSTEM)                    # 応答を表示
		_update_prompt()
		return

	var command_line = text.strip_edges()
	if command_line == "":
		# 空コマンドの場合もプロンプトを再表示
		_update_prompt()
		return

	# OutputType.SYSTEM を使用することで、_print が余計な "> " を付加するのを防ぎます
	var prompt = _get_current_dir_name() + " > "
	# trimmed_text を使用するように変更
	_print(prompt + trimmed_text, OutputType.SYSTEM)
	
	command_history.append(command_line)
	history_index = command_history.size()
	input_line.clear()

	var parts = trimmed_text.split(" ", false)
	var cmd_name = parts[0]
	var args = parts.slice(1, parts.size())

	# 既存のコマンド処理
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

	# コマンド実行後のプロンプト表示
	_update_prompt()

#func _update_prompt():
	#var prompt = _get_current_dir_name() + " > "
	## InputLineのプレースホルダーを更新
	#input_line.placeholder_text = prompt

func _print(message: String, type: OutputType = OutputType.SYSTEM):
	var prefix = ""
	
	match type:
		OutputType.INPUT:
			prefix = "> "
		OutputType.SYSTEM:
			prefix = ""
	# 1. テキストを出力ボックスに追加
	output_box.text += prefix + message + "\n"
	
	# 2. スクロール処理を遅延実行する関数を呼び出す
	# テキストがTextEditに適用され、レイアウトが更新されてからスクロールバーの値を変更するのが確実
	# call_deferred() を使用
	#call_deferred("_scroll_to_bottom") 
	call_deferred("_scroll_output_to_end")
	
	input_line.grab_focus()

# 最下段までスクロールを実行するための遅延関数
func _scroll_to_bottom():
	# VScrollBarノードの最大スクロール値を取得
	var max_scroll_value = scrollbar.get_max()
	
	# VScrollBarの値を最大値に設定し、最下部までスクロール
	# set_value() で直接設定
	scrollbar.set_value(max_scroll_value)

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

# 現在のパスからディレクトリ名を取得する関数
func _get_current_dir_name() -> String:
	# 例: "/home/user/logs" -> "logs"
	# 例: "/" -> "/"
	
	if current_path == "/":
		return "/"
		
	var path_segments = current_path.split("/")
	
	# 末尾の空文字列（例: /home/user/ の最後の /）を削除
	# Godot 4.xでは、最後の要素は [-1] または size() - 1
	if path_segments.size() > 0 and path_segments[-1].is_empty():
		path_segments.remove_at(path_segments.size() - 1) # pop_back()の代わりにremove_at(last_index)を使用
	
	# パスがセグメントを持つ場合、最後のセグメント（ディレクトリ名）を返す
	if path_segments.size() > 0:
		return path_segments[-1] # 配列の最後の要素は [-1] で取得可能
		
	# パスがルート '/' まで遡った場合
	return "/"

# 💡【修正】最下段までスクロールを実行するための遅延関数
func _scroll_output_to_end():
	var total_lines = output_box.get_line_count()
	
	if total_lines > 0:
		# 1. キャレットを最終行の次の行に設定（最後の表示可能位置へ）
		# total_lines を指定することで、文書の末尾までキャレットを移動させます。
		output_box.set_caret_line(total_lines) 
		# 列はどこでもいいが、キャレット自体を動かすのが目的
		output_box.set_caret_column(0) 
		
		# 2. 二重遅延でScrollBarの値を最大に設定
		# これにより、TextEditのコンテンツサイズが確定した後にスクロール処理が実行されます。
		call_deferred("_force_scrollbar_max")

# ScrollBarの値を最大にする二重遅延用の関数
func _force_scrollbar_max():
	# ScrollContainerのScrollBarを操作
	var max_scroll_value = scrollbar.get_max()
	
	# スクロールバーの値を最大値に設定し、最下部までスクロール
	# これで、最後に表示されたテキストの行まで正確にスクロールされます。
	scrollbar.set_value(max_scroll_value)

# プロンプト接頭辞の設定/リセット関数
func set_prompt_prefix(new_prefix: String):
	prompt_prefix = new_prefix
	_update_prompt()

func reset_prompt_prefix():
	prompt_prefix = "user@cyb-pc:/$ "
	_update_prompt()

func _update_prompt():
	var dir_name = _get_current_dir_name()
	
	# 💡 ftp接続中は ftp.gd が設定した接頭辞を優先
	var current_prompt = prompt_prefix 
	if current_prompt == "user@cyb-pc:/$ ":
		current_prompt = "user@cyb-pc:%s$ " % dir_name

	#$VBoxContainer/InputLine/PromptLabel.text = current_prompt
	# InputLineのプレースホルダーを更新
	input_line.placeholder_text = current_prompt
