extends Control

# NetworkService (Autoload) が通信のルーティングを担うと仮定
# プレイヤー自身のIP (クライアント側) は NetworkService の仕様に依存しますが、
# ここではダミーとして '192.168.1.1' を使用します
const CLIENT_IP = "192.168.1.1"

# @onready var の定義は HttpClientUI.tscn のノード名に合わせる
@onready var url_input = $VBoxContainer/HBoxRequest/URLInput
@onready var method_select = $VBoxContainer/HBoxRequest/MethodSelect
@onready var send_button = $VBoxContainer/HBoxRequest/SendButton
@onready var headers_input = $VBoxContainer/TabContainer/Headers/TextEdit
@onready var body_input = $VBoxContainer/TabContainer/Body/TextEdit
@onready var response_output = $VBoxContainer/TabContainer/Response/TextEdit

func _ready():
	send_button.pressed.connect(_on_send_button_pressed)
	# 初期メソッドを設定
	method_select.add_item("GET", 0)
	method_select.add_item("POST", 1)
	method_select.select(0)
	
	# 初期URLの提案 (WebサーバーのIPとポートを想定)
	url_input.text = "http://192.168.1.10:80/"
	
	# 出力エリアを読み取り専用に
	response_output.editable = false
	
	# POST選択時にのみBodyタブを有効化
	method_select.item_selected.connect(_on_method_selected)
	_on_method_selected(method_select.selected)

# メソッド選択時の処理
func _on_method_selected(index: int):
	var method = method_select.get_item_text(index)
	# Bodyタブ（インデックス2）の無効化/有効化
	$VBoxContainer/TabContainer.set_tab_disabled(2, method == "GET")

# 送信ボタンが押された時のメインロジック
func _on_send_button_pressed():
	if not is_instance_valid(NetworkService):
		response_output.text = "[ERROR] NetworkService (Autoload) が利用できません。"
		return

	var url_text = url_input.text.strip_edges()
	var method = method_select.get_item_text(method_select.selected)
	
	# 1. URLのパース (IP, Port, Path)
	# 例: http://192.168.1.10:80/api/login
	var url_parts = _parse_url(url_text)
	if url_parts.status == "error":
		response_output.text = url_parts.message
		return

	# 2. ヘッダーのパース (簡易的な処理)
	var headers = _parse_headers(headers_input.text)
	
	# 3. リクエストデータの構築
	var request_data: Dictionary = {
		"method": method,
		"path": url_parts.path,
		"headers": headers,
		"body": body_input.text if method == "POST" else "",
		"protocol": "http" # WebServerが認識するプロトコル
	}
	
	response_output.text = "--- Sending Request ---\n"
	response_output.text += "TARGET: %s:%d\nMETHOD: %s\nPATH: %s\n\n" % [
		url_parts.ip, url_parts.port, method, url_parts.path
	]
	
	# 4. NetworkService経由で通信をシミュレート
	var raw_response = CF_NetworkService.route_connection(
		CLIENT_IP, 
		url_parts.ip, 
		"web", # VirtualHost.gd で WebServer にルーティングするためのプロトコル
		url_parts.port, 
		request_data
	)
	
	# 5. 応答の表示
	_display_response(raw_response)

# URLを解析してIP, Port, Pathを抽出
func _parse_url(url: String) -> Dictionary:
	# http:// は必須
	if not url.begins_with("http://"):
		return {"status": "error", "message": "[ERROR] URLは 'http://' で始まる必要があります。"}
	
	var sanitized_url = url.trim_prefix("http://")
	var ip_port_path = sanitized_url.split("/", 2)
	
	var ip_port = ip_port_path[0]
	var path = "/" + ip_port_path.get(1, "") # パスがない場合はルートにする
	
	var parts = ip_port.split(":", 2)
	var ip = parts[0]
	var port = parts.get(1, "80").to_int() # ポート指定がない場合はデフォルト80
	
	# 簡易的なIP/Portチェック
	if not ip.is_valid_ip_address() or port <= 0:
		return {"status": "error", "message": "[ERROR] IPまたはポートが無効です。"}
	
	return {"status": "success", "ip": ip, "port": port, "path": path}

# ヘッダー文字列を辞書にパース (簡易的な処理)
# 例: "Cookie: session=abc" -> {"Cookie": "session=abc"}
func _parse_headers(header_string: String) -> Dictionary:
	var headers: Dictionary = {}
	var lines = header_string.split("\n", false)
	
	for line in lines:
		var trimmed_line = line.strip_edges()
		if trimmed_line.is_empty():
			continue
			
		var parts = trimmed_line.split(":", 1)
		if parts.size() == 2:
			var key = parts[0].strip_edges()
			var value = parts[1].strip_edges()
			headers[key] = value
			
	return headers

# サーバー応答を表示
func _display_response(response: Variant):
	var output = "\n--- Server Response ---\n"
	
	# WebServer.gd の応答が Dictionary 形式であることを想定
	if typeof(response) == TYPE_DICTIONARY:
		# 例: {"status": 200, "headers": {...}, "body": "..."}
		var status_code = response.get("status", 500)
		output += "HTTP Status: %d\n" % status_code
		
		var headers = response.get("headers", {})
		output += "Headers:\n"
		for key in headers.keys():
			output += "  %s: %s\n" % [key, headers[key]]
			
		output += "\nBody:\n"
		output += response.get("body", "[No Content]")
		
	elif typeof(response) == TYPE_STRING:
		# 文字列の場合はそのまま表示 (ネットワークエラーなど)
		output += "[RAW RESPONSE]\n" + str(response)
	else:
		output += "[UNKNOWN RESPONSE TYPE]\n" + str(response)

	response_output.text += output
