# MissionManager.gd
extends Node

# ミッションJSONが格納されているディレクトリ
const MISSION_EXTERNAL_DIR_NAME = "missions"
const MISSION_DIR = "res://missions/"
# 読み込まれた全ミッションのメタデータを格納する辞書
var loaded_missions: Dictionary = {}

func _ready():
	load_all_missions()

# ディレクトリ内のすべてのJSONファイルを読み込む
func load_all_missions():
	# 💡 修正: 実行環境に応じてパスを切り替える
	var base_path: String
	
	# Godotエディタ内またはエクスポートされた実行ファイル内かをチェック
	# has_feature("editor") はエディタ内での実行を検出
	if OS.has_feature("editor"):
		# 開発環境の場合は res:// を使用し、完全なOSパスに変換
		# 💡 修正: PROJECT_SETTINGS -> ProjectSettings (シングルトン) に変更
		base_path = ProjectSettings.globalize_path(MISSION_DIR)
	elif OS.has_feature("mobile") or OS.has_feature("web"):
		# モバイルやWebの場合は res:// を使用
		# globalize_path は使わず、そのまま相対パスを使用（または FileAccess.get_file_as_bytes で対応）
		# ここではシンプルに MISSION_DIR の相対パスを使用する戦略を採用
		base_path = MISSION_DIR
	else:
		# 実行ファイル（.exeなど）の場合は、実行ファイルと同じディレクトリを使用
		var exe_dir = OS.get_executable_path().get_base_dir()
		base_path = exe_dir.path_join(MISSION_EXTERNAL_DIR_NAME)

	print("Mission search path: ", base_path)
	
	# 💡 修正: base_path が "res://" から始まる場合は DirAccess.open() にそのまま渡す
	var dir: DirAccess = null
	
	if base_path.begins_with("res://"):
		dir = DirAccess.open(base_path)
	else:
		dir = DirAccess.open(base_path)

	
	if dir == null:
		# 外部パスで開けなかった場合、開発環境のres://にフォールバック（デバッグ用）
		if not OS.has_feature("editor"):
			printerr("Error: Could not open mission directory: ", base_path)
			print("Attempting fallback to res:// path...")
		
		# 開発環境からの実行、または外部読み込み失敗時のフォールバック
		# 💡 修正: PROJECT_SETTINGS -> ProjectSettings (シングルトン) に変更
		var fallback_path = ProjectSettings.globalize_path(MISSION_DIR)
		dir = DirAccess.open(fallback_path)
		
		if dir == null:
			printerr("FATAL: Could not open mission directory even on res:// path.")
			return
		# フォールバックした場合は base_path も更新 (後の file_path 作成に使用)
		base_path = fallback_path 
		
	# .json ファイルをフィルター
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			# 💡 修正: DirAccessが返すファイル名とbase_pathを結合してファイルパスを作成
			var file_path = base_path.path_join(file_name) 
			
			# 🚨 FileAccess.open() には完全なOSパスを渡す
			var mission_data = load_mission_json(file_path)
			
			if mission_data:
				var mission_id = mission_data.get("mission_id", file_name.replace(".json", ""))
				loaded_missions[mission_id] = mission_data
				print("Loaded mission: ", mission_id, " (", mission_data.get("title", "No Title"), ") from ", file_path)
		
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if loaded_missions.is_empty():
		print("Warning: No missions loaded.")

		
# IDからミッションデータを取得
func get_mission_data(mission_id: String) -> Dictionary:
	if loaded_missions.has(mission_id):
		return loaded_missions[mission_id]
	return {} # 見つからない場合は空の辞書を返す


# 単一のJSONファイルを読み込むヘルパー関数
func load_mission_json(path: String) -> Dictionary:
	# 💡 ファイルのオープン
	var file = FileAccess.open(path, FileAccess.READ) 
	if file == null:
		# Godot 4.xでは get_open_error() でエラー詳細を取得できます
		printerr("Error: Failed to open mission file: ", path, " Error: ", FileAccess.get_open_error())
		return {}

	# 💡 ファイル内容の読み込み
	var content = file.get_as_text()
	
	# 💡 JSON文字列のパース
	var json_result = JSON.parse_string(content)
	
	if json_result == null:
		printerr("Error: Failed to parse JSON in file: ", path)
		# JSONエラーの詳細ログが必要な場合は以下を使用
		# printerr("JSON Error: ", JSON.get_error_line(), ": ", JSON.get_error_message())
		return {}

	# 成功した場合、パース結果を返す
	return json_result
