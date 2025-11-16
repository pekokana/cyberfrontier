# MissionState.gd (AutoLoadとして登録)
extends Node

# ミッション開始時に MissionExecutionUI から設定されるデータ
var mission_network_data: Dictionary = {}

# プレイヤーがスキャンで見つけたポート情報を保持する (スキャン結果の状態)
# 構造: { "192.168.1.100": { "22": "SSH", "8080": "HTTP" }, ... }
var scanned_results: Dictionary = {}

# スキャン結果が更新されたことを通知するシグナル
signal scan_results_updated(ip_address)

# MissionExecutionUI.gd から呼び出され、ミッション開始時に初期化する
func initialize_mission_data(data: Dictionary):
	# MissionExecutionUI から渡されたミッションデータからネットワーク情報を抽出
	mission_network_data = data.get("network", {})
	# 過去の結果をクリア
	scanned_results.clear()
	print("MissionState initialized with network data.")

# 外部（PortScannerやTerminalCommand）からスキャン結果を保存する
func save_scan_result(ip: String, ports: Dictionary) -> void:
	if not scanned_results.has(ip):
		scanned_results[ip] = {}
	
	# 新しく発見されたポートを追加
	for port in ports:
		scanned_results[ip][port] = ports[port]
	
	# ネットワークマップなどに更新を通知
	scan_results_updated.emit(ip)

# スキャン結果を取得する
func get_scanned_results_for(ip: String) -> Dictionary:
	return scanned_results.get(ip, {})
