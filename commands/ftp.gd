## res://commands/ftp.gd
extends RefCounted

#const NetworkService = preload("res://scripts/services/NetworkService.gd")

var console # terminal_ui.gd のインスタンス
var description: String = "Connect to an FTP server."
var current_session: Dictionary = {} # { ip: "...", port: 21, logged_in: false }

# 💡 クライアント側のIPアドレスを固定値として仮定
const CLIENT_IP = "192.168.1.1" 

func execute(args: Array) -> String:
	if args.is_empty():
		return '' #_handle_session_input(null)
	
	if args.size() < 1:
		return "Usage: ftp <ip_address> [port]"

	var target_ip = args[0]
	var target_port = 21 # デフォルトポート
	if args.size() > 1 and args[1].is_valid_int():
		target_port = args[1].to_int()

	if target_ip.to_lower() == "quit":
		return _handle_session_input("QUIT")

	if not current_session.is_empty():
		# 既に接続中の場合
		return "ERROR: Already connected to %s. Type 'quit' to disconnect." % current_session.ip
		
	# 新規接続を試みる
	var response = _send_command(target_ip, target_port, "CONNECT", [])
	
	if response.begins_with("220"): # 220 Virtual FTP Server ready
		current_session = { "ip": target_ip, "port": target_port, "logged_in": false }
		console.set_prompt_prefix("ftp@%s>" % target_ip)
		return response + "\nConnected. Use 'USER <name>', 'PASS <pass>', 'LIST', 'RETR <file>', 'QUIT'."
	else:
		return response # Connection refused などのエラー

# ターミナルからのコマンド入力処理 (接続後のコマンド処理)
func _handle_session_input(input: String):
	if current_session.is_empty() and input != null:
		return "ERROR: Not connected. Use 'ftp <ip>' to connect."
	
	var parts: Array[String] = []
	if input != null:
		parts = input.split(" ", false)

	var command = parts[0].to_upper() if parts.size() > 0 else ""
	var args = parts.slice(1) if parts.size() > 1 else []

	if command == "QUIT":
		var response = _send_command(current_session.ip, current_session.port, "QUIT", [])
		current_session = {}
		console.reset_prompt_prefix()
		return response
		
	if current_session.is_empty():
		return "" # 初期状態、またはコマンドなし

	# サービスにコマンドを送信
	var response = _send_command(current_session.ip, current_session.port, command, args)
	
	# ログイン状態の更新 (PASSコマンドの結果をチェック)
	if command == "PASS" and response.begins_with("230"):
		current_session.logged_in = true

	return response

# NetworkServiceを経由してサーバーにデータを送信
func _send_command(ip: String, port: int, command: String, args: Array) -> String:
	if is_instance_valid(NetworkService):
		var data = { "command": command, "args": args }
		var result = CF_NetworkService.route_connection(CLIENT_IP, ip, "ftp", port, data)
		return str(result)
	return "ERROR: NetworkService not available."
