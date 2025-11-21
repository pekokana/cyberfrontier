extends BaseServer
class_name DBServer

# 内部データストア { "table_name": [ {row1}, {row2} ] }
var data_store: Dictionary = {}

func _setup_service_specifics():
	service_type = "DB"
	# configから初期データをロード
	data_store["users"] = config.get("initial_data_users", [
		{"id": 1, "username": "admin", "password_hash": "a1b2c3d4", "role": "admin"},
		{"id": 2, "username": "guest", "password_hash": "e5f6g7h8", "role": "user"}
	])
	data_store["secrets"] = config.get("initial_data_secrets", [
		{"id": 1, "data": "FLAG{SQL_INJECTION_WEAK}"}
	])
	print("DBServer initialized on port %d with %d tables." % [service_port, data_store.size()])

# 通信処理 (SQLクエリをシミュレート)
# data は { "query": "SELECT * FROM users" } を想定
func handle_connection(source_ip: String, target_ip: String, data: Dictionary) -> Variant:
	var query = data.get("query", "").strip_edges()
	if query.is_empty():
		return "DB_ERROR: No query provided."

	var lower_query = query.to_lower()

	# SQLインジェクションの脆弱性シミュレーション（簡易版）
	# クエリに ' OR '1'='1' が含まれていれば、機密データを返す
	if lower_query.contains("select") and lower_query.contains("' or '1'='1"):
		# SQLi成功！secretsテーブルのデータをリークさせる
		var secret_data = data_store["secrets"]
		return "DB_RESULT: SQLi Successful. Leaked data: " + str(secret_data)
		
	elif lower_query.begins_with("select") and lower_query.contains("users"):
		# 正常なクエリのシミュレーション
		var user_count = data_store["users"].size()
		return "DB_RESULT: Found %d users." % user_count
		
	elif lower_query.begins_with("select"):
		return "DB_RESULT: Query executed, 0 rows returned."
		
	# その他の操作
	return "DB_ERROR: Unsupported query type or syntax error."
