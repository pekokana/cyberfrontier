# res://scripts/services/WebServer.gd
extends BaseServer
class_name WebServer

# NetworkService (Autoload) はプロジェクト内で利用可能である必要があります。

# サービスのセットアップ
func _setup_service_specifics():
	service_type = "WEB"

	# 設定からルートパスを取得 (デフォルト: /vfs/www)
	var root_path = config.get("root_path", "/vfs/www")
	print("WebServer initialized on port %d. VFS Root: %s" % [service_port, root_path])
	
	# ============================================================
	# JSON定義のファイルをVFSに作成するロジック
	# ============================================================
	var files = config.get("files", [])
	for file_data in files:
		var file_name = file_data.get("name", "")
		var file_content = file_data.get("content", "")
		
		if not file_name.is_empty():
			# フルパスを作成 (例: /vfs/www/index.html)
			var full_path = root_path.path_join(file_name)
			
			# VFSにファイルを作成 (VFSCoreのヘルパー関数を使用)
			# ※ vfs_core は BaseServer で設定されている VFSCore への参照
			if is_instance_valid(vfs_core):
				vfs_core._create_node_from_path(full_path, "file", file_content)
				print("WebServer: Created VFS file: ", full_path)
			else:
				printerr("WebServer Error: vfs_core is invalid, cannot create files.")



# HTTPリクエストの処理 (AppServerへのルーティング)
# data: { "method": "GET/POST", "path": "/path", "headers": {...}, "body": "..." }
func handle_connection(source_ip: String, target_ip: String, data: Dictionary) -> Variant:
	var method = data.get("method", "GET").to_upper()
	var path = data.get("path", "/")
	var headers = data.get("headers", {})
	var body = data.get("body", "")

	# ルートパスを取得 (デフォルト: /vfs/www)
	var root_path = config.get("root_path", "/vfs/www")

	# ============================================================
	# 1. 静的ファイル処理の一般化 (既存の「1. ルートパスの静的ファイル処理」を置き換える)
	# ============================================================
	
	var target_path = path 
	
	# リクエストパスが "/" の場合、VFS内では "index.html" に変換する
	if path == "/":
		target_path = "/index.html"
	
	# VFS上の絶対パスを生成 (例: /vfs/www/robots.txt)
	# target_pathの先頭の "/" を削除してから結合する (path_joinは自動で "/" を処理するため)
	var file_path = root_path.path_join(target_path.trim_prefix("/"))
	
	# VFSからファイルを読み込む
	var content = vfs_core.read_file(file_path)
	
	# コンテンツが取得できたかチェック (vfs_core.read_file()はエラー時に"Error:..."を返す想定)
	if not content.begins_with("Error:"):
		# 簡易的なMIMEタイプ判定
		var content_type = "text/plain"
		if file_path.ends_with(".html"):
			content_type = "text/html"
		elif file_path.ends_with(".txt"):
			content_type = "text/plain"

		return {
			"status": 200, 
			"headers": {"Content-Type": content_type},
			"body": content
		}

	# ============================================================
	# 2. APIエンドポイントへのルーティング (既存の処理をそのまま利用)
	# ============================================================
	# (省略: 既存の /api/ 処理はそのまま維持されます)
	if path.begins_with("/api/"):
		# ... 既存の /api/ の処理ロジック ...
		# (AppServerへのルーティング処理全体をここにペーストし直してください)
		
		# --- ルーティングの終端 ---
		var api_call = path.trim_prefix("/api/").split("/")[0]
		var app_ip = config.get("app_ip", "10.0.0.10")
		var app_port = config.get("app_port", 8080)
		
		var app_payload: Dictionary = {
			"api_call": api_call,
			"payload": {
				"method": method,
				"path": path,
				"headers": headers,
				"body": body
			}
		}
		
		var app_response = CF_NetworkService.route_connection(
			target_ip,   
			app_ip,  
			"app",   
			app_port, 
			app_payload
		)
		
		if typeof(app_response) == TYPE_DICTIONARY and app_response.has("status"):
			return _format_app_response(app_response, headers)
		else:
			return {"status": 500, "headers": {}, "body": "Internal Application Error."}


	# 3. 静的ファイルも見つからず、APIルーティングにもマッチしない場合
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
