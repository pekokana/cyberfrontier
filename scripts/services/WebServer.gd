# res://scripts/services/WebServer.gd
extends "res://scripts/services/BaseServer.gd"

# NetworkService (Autoload) はプロジェクト内で利用可能である必要があります。

# サービスのセットアップ
func _setup_service_specifics():
	service_type = "WEB"
	print("WebServer initialized on port %d. VFS Root: %s" % 
		[service_port, config.get("root_path", "/vfs/www")])

# HTTPリクエストの処理 (AppServerへのルーティング)
# data: { "method": "GET/POST", "path": "/path", "headers": {...}, "body": "..." }
func handle_connection(source_ip: String, target_ip: String, data: Dictionary) -> Variant:
	var method = data.get("method", "GET").to_upper()
	var path = data.get("path", "/")
	var headers = data.get("headers", {})
	var body = data.get("body", "")

	# 1. ルートパスの静的ファイル処理 (Webサーバー機能)
	if path == "/":
		# VFSから index.html を取得
		var file_path = config.get("root_path", "/vfs/www").path_join("index.html")
		var content = vfs_core.read_file(file_path)
		
		if not content.begins_with("Error:"):
			return {
				"status": 200, 
				"headers": {"Content-Type": "text/html"},
				"body": content
			}

	# 2. APIエンドポイントへのルーティング (AppServerへの転送)
	# 例: /api/login, /api/user/profile など
	if path.begins_with("/api/"):
		# PathをAPIコール名に変換 (例: /api/login -> login)
		var api_call = path.trim_prefix("/api/").split("/")[0] 
		
		# AppServerのIPとポートをConfigから取得 (AppServerとの内部連携を想定)
		var app_ip = config.get("app_ip", "10.0.0.10") 
		var app_port = config.get("app_port", 8080)
		
		# AppServerに渡すペイロードを構築
		# HTTPリクエストのヘッダー、ボディ、メソッドをまとめて渡す
		var app_payload: Dictionary = {
			"api_call": api_call,
			"payload": {
				"method": method,
				"path": path,
				"headers": headers,
				"body": body
				# SQLiミッションで AppServer.gd の _handle_login が直接使用する
				# username/password は body や headers からパースする必要がある
			}
		}
		
		# 💡 ここで AppServer.gd と連携させる
		var app_response = CF_NetworkService.route_connection(
			target_ip,   # AppServerへの接続元はWebサーバーのIP
			app_ip, 
			"app",       # AppServer.gd がリッスンするプロトコル
			app_port, 
			app_payload
		)
		
		# AppServerからの応答をHTTP応答に変換して返す
		if typeof(app_response) == TYPE_DICTIONARY and app_response.has("status"):
			return _format_app_response(app_response, headers)
		else:
			return {"status": 500, "headers": {}, "body": "Internal Application Error."}

	# 3. ファイルが見つからない場合
	return {"status": 404, "headers": {}, "body": "Not Found: " + path}

# AppServerからの汎用応答をHTTP形式に変換
func _format_app_response(app_response: Dictionary, request_headers: Dictionary) -> Dictionary:
	var status_code = 200
	var response_headers = {"Content-Type": "application/json"}
	var response_body = JSON.stringify(app_response)
	
	# セッションIDがAppServerから返された場合、Set-Cookieヘッダーに追加
	if app_response.has("session_id"):
		response_headers["Set-Cookie"] = "session_id=" + app_response.session_id + "; HttpOnly"

	# AppServerのステータスに基づいてHTTPステータスコードを調整
	if app_response.get("status") == "fail":
		status_code = 401 # 認証失敗など
	
	# SQLi成功時の特別な応答 (AppServer.gdと連携)
	if app_response.has("flag_info"):
		response_body = "SUCCESS! Flag Data Retrieved: " + app_response.flag_info
		status_code = 200 # 攻撃成功はHTTP上は成功とみなす
		response_headers["Content-Type"] = "text/plain"

	return {
		"status": status_code,
		"headers": response_headers,
		"body": response_body
	}
