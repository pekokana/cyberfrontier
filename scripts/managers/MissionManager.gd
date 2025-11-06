# MissionManager.gd
extends Node

# ミッションJSONが格納されているディレクトリ
const MISSION_DIR = "res://missions/"
# 読み込まれた全ミッションのメタデータを格納する辞書
var loaded_missions: Dictionary = {}

func _ready():
	load_all_missions()

# ディレクトリ内のすべてのJSONファイルを読み込む
func load_all_missions():
	var dir = DirAccess.open(MISSION_DIR)
	
	if dir == null:
		print("Error: Could not open mission directory: ", MISSION_DIR)
		return

	# .json ファイルをフィルター
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = MISSION_DIR.path_join(file_name)
			var mission_data = load_mission_json(file_path)
			
			if mission_data:
				# mission_id をキーとして辞書に格納
				var mission_id = mission_data.get("mission_id", file_name.replace(".json", ""))
				loaded_missions[mission_id] = mission_data
				print("Loaded mission: ", mission_id, " (", mission_data.get("title", "No Title"), ")")
		
		file_name = dir.get_next()
	dir.list_dir_end()
	
	if loaded_missions.is_empty():
		print("Warning: No missions loaded.")

# 単一のJSONファイルを読み込むヘルパー関数
func load_mission_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Error opening file: ", path)
		return {}

	var content = file.get_as_text()
	var json_result = JSON.parse_string(content)
	
	if json_result is Dictionary:
		return json_result
	else:
		print("Error parsing JSON in file: ", path)
		return {}
		
# IDからミッションデータを取得
func get_mission_data(mission_id: String) -> Dictionary:
	return loaded_missions.get(mission_id, {})
