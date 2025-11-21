extends BaseServer
class_name APServer

# --- 設定キー (config Dictionaryで設定) ---
const DB_IP = "db_ip"
const DB_PORT = "db_port"
const VULN_SQLI = "vulnerability_sqli"
const VULN_SESSION = "vulnerability_session_hijack"

# --- 内部状態 ---
var db_target_ip: String = "127.0.0.1"
var db_target_port: int = 3306
var is_sqli_vulnerable: bool = false
var is_session_weak: bool = false

# ⚠️ 注意: NetworkService (ルーター) は Autoload/Singleton としてプロジェクト内で利用可能である必要があります。

# サービスのセットアップと設定のロード
func _setup_service_specifics():
	service_type = "APP"
	# 設定からDB接続情報と脆弱性フラグをロード
	db_target_ip = config.get(DB_IP, "127.0.0.1")
	db_target_port = config.get(DB_PORT, 3306)
	is_sqli_vulnerable = config.get(VULN_SQLI, false)
	is_session_weak = config.get(VULN_SESSION, false)
	
	print("AppServer initialized on port %d. DB target: %s:%d. SQLi Vulnerable: %s" % 
		[service_port, db_target_ip, db_target_port, str(is_sqli_vulnerable)])

# 通信処理 (Webサーバーからの内部APIコールを想定)
# data: { "api_call": "login", "payload": { ... } }
func handle_connection(source_ip: String, target_ip: String, data: Dictionary) -> Variant:
	var api_call = data.get("api_call", "unknown").to_lower()
	var payload = data.get("payload", {})
	
	# 💡 APIルーター: エンドポイントを追加することで拡張可能
	match api_call:
		"login":
			return _handle_login(payload, source_ip)
		"get_user_profile":
			return _handle_user_profile(payload)
		"search_users":
			return _handle_search_users(payload)
		"get_db_flag": # 攻撃者向けのカスタムエンドポイント
			return _handle_get_db_flag(payload)
		_:
			# 未定義のエンドポイントはエラー応答
			return {"status": "error", "message": "API endpoint not found: " + api_call}

# ==============================================================================
# APIハンドラー
# ==============================================================================

# ログイン処理
func _handle_login(payload: Dictionary, source_ip: String) -> Dictionary:
	var username = payload.get("username", "").strip_edges()
	var password = payload.get("password", "").strip_edges()

	# 1. DBクエリの生成
	var db_query: String
	if is_sqli_vulnerable:
		# 🚨 脆弱なロジック: ユーザー入力を直接クエリに埋め込む
		# SQLiの成功時にフラグを含むデータを取得できるように、DBServer側と連携させる
		db_query = "SELECT * FROM users WHERE username = '" + username + "' AND password = '" + password + "'"
	else:
		# ✅ 安全なロジックのシミュレーション
		db_query = "SELECT * FROM users WHERE username = ? AND password = ?"

	# 2. DBとの通信
	var db_response = _communicate_with_db(db_query)

	if db_response.status == "DB_RESULT":
		if db_response.data.size() > 0 or db_response.data.has("flag_data"):
			# 認証成功、またはSQLiによるバイパス成功
			var user_data = db_response.data.get(0, {"username": "Attacker", "id": 999})
			var session_id = _generate_session_id(user_data, source_ip)
			
			return {
				"status": "success", 
				"user": user_data.get("username"), 
				"session_id": session_id,
				"flag_info": db_response.data.get("flag_data") # SQLi成功時にフラグが含まれることを期待
			}
		else:
			return {"status": "fail", "message": "Invalid credentials or user not found."}
	
	return {"status": "error", "message": "DB communication failed."}

# ユーザー検索機能 (SQLiの別の攻撃面)
func _handle_search_users(payload: Dictionary) -> Dictionary:
	var query_string = payload.get("query", "").strip_edges()
	
	var db_query: String
	if is_sqli_vulnerable:
		# 🚨 脆弱なロジック: 検索文字列を直接LIKE句に埋め込む
		db_query = "SELECT username, email FROM users WHERE username LIKE '%" + query_string + "%'"
	else:
		# ✅ 安全なロジック
		db_query = "SELECT username, email FROM users WHERE username LIKE ?"

	var db_response = _communicate_with_db(db_query)
	
	if db_response.status == "DB_RESULT":
		return {"status": "success", "results": db_response.data}
		
	return {"status": "error", "message": "Search failed."}

# 機密性の高いデータ取得API (認可の欠陥/認証バイパスのミッション用)
func _handle_get_db_flag(payload: Dictionary) -> Dictionary:
	var user_role = payload.get("role", "guest")
	
	# 💡 認可の欠陥 (Insecure Direct Object Reference / IDOR) のシミュレーション
	# 本来はDBからロールを確認すべきだが、ここではペイロードを信用してしまう
	if user_role == "admin" or is_sqli_vulnerable:
		# DBからフラグテーブルを全件取得するクエリ
		var db_query = "SELECT * FROM flag_secrets"
		var db_response = _communicate_with_db(db_query)
		
		if db_response.status == "DB_RESULT":
			return {"status": "success", "secret_data": db_response.data}
	
	return {"status": "error", "message": "Permission denied."}


# ユーザープロフィール取得
func _handle_user_profile(payload: Dictionary) -> Dictionary:
	# 認可のロジックはWebサーバー側で行うことが多いが、ここでもチェックをシミュレート
	# 例: セッションの有効期限や権限をチェック
	return {"status": "success", "profile": "User information placeholder."}

# ==============================================================================
# 内部ヘルパー関数
# ==============================================================================

# セッションIDを生成 (Session Hijackingのシミュレーション用)
func _generate_session_id(user_data: Dictionary, client_ip: String) -> String:
	
	if is_session_weak:
		# 🚨 脆弱なセッションID生成 (例: ユーザーIDとIPをそのまま結合 -> 予測または固定化が可能)
		var base = "%s-%s" % [str(user_data.get("id", 0)), client_ip.replace(".", "")]
		return "WEAK_SID_" + base.sha1_text() # SHA1でハッシュ化するが、元情報が貧弱
	else:
		# ✅ 安全なセッションID生成 (ランダム性の高い文字列)
		# ランダム値、タイムスタンプ、ユーザー情報を複雑に混ぜる
		var base = "%s%d%s" % [str(randi()), Time.get_ticks_usec(), user_data.get("username", "")]
		return "STRONG_SID_" + base.sha256_text()

# DBサーバーとの通信をシミュレート
func _communicate_with_db(query: String) -> Dictionary:
	if not is_instance_valid(NetworkService):
		printerr("CRITICAL ERROR: NetworkService Autoload is not available!")
		return {"status": "error", "message": "Network Service unavailable"}

	var connection_data = { "query": query }
	
	# AppServerがDBにアクセスするため、送信元IPはAppServerがバインドされているIPを使用
	var source_ip_for_db = db_target_ip # 内部通信の発信元 (VirtualHostのIP)
	
	# NetworkServiceを介してDBにルーティング
	var db_response_raw = CF_NetworkService.route_connection(
		source_ip_for_db,
		db_target_ip,
		"db",
		db_target_port,
		connection_data
	)
	
	# DBServer.gdの応答形式を解析
	if typeof(db_response_raw) == TYPE_STRING:
		var raw_str = db_response_raw.strip_edges()
		
		# 💡 DBServer側でSQLi成功時にフラグ情報を含む文字列が返されることを想定
		if raw_str.contains("SQLi Successful"):
			return {"status": "DB_RESULT", "data": {"flag_data": raw_str}}
			
		if raw_str.begins_with("DB_RESULT:"):
			# 簡易的な成功応答
			return {"status": "DB_RESULT", "data": [{"result_text": raw_str.trim_prefix("DB_RESULT:").strip_edges()}]}
		
		return {"status": "DB_ERROR", "message": raw_str}
	
	if typeof(db_response_raw) == TYPE_DICTIONARY:
		return db_response_raw
		
	return {"status": "error", "message": "Unknown DB response format."}
