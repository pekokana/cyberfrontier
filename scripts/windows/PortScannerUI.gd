# PortScannerUI.gd
extends Control

@onready var ip_input = $VBoxContainer/HBoxContainer/IPInput
@onready var scan_button = $VBoxContainer/HBoxContainer/ScanButton
@onready var results_tree = $VBoxContainer/ResultsTree

func _ready():
	scan_button.pressed.connect(_on_scan_button_pressed)
	# Tree の設定
	results_tree.set_hide_root(true)
	results_tree.set_columns(3)
	results_tree.set_column_title(0, "IP Address")
	results_tree.set_column_title(1, "Port")
	results_tree.set_column_title(2, "Service")

	# MissionStateからの更新を監視
	MissionState.scan_results_updated.connect(_on_scan_results_updated, CONNECT_DEFERRED)

func _on_scan_button_pressed():
	var target_ip = ip_input.text.strip_edges()
	if target_ip.is_empty():
		return
	
	scan_button.disabled = true
	scan_button.text = "Scanning..."
	
	var network_data = MissionState.mission_network_data.get("scan_data", {})
	var target_server = network_data.get(target_ip)

	if not target_server:
		_display_error(target_ip + " is not a valid target IP.")
		return
	
	var discovered_ports = {}
	
	# スキャンシミュレーション
	# ここでは非同期処理は行わず、即座に結果を返す
	for port_key in target_server.ports:
		discovered_ports[port_key] = target_server.ports[port_key]
	
	# スキャン結果を状態管理に保存 (MissionStateが自動でシグナルを発行)
	MissionState.save_scan_result(target_ip, discovered_ports)
	
	# UIを更新
	_display_results(target_ip, discovered_ports)
	
	scan_button.disabled = false
	scan_button.text = "Scan"

# スキャン結果をTreeビューに表示する
func _display_results(ip: String, ports: Dictionary):
	results_tree.clear()
	var root = results_tree.create_item()
	
	for port_key in ports.keys():
		var item = results_tree.create_item(root)
		item.set_text(0, ip)
		item.set_text(1, str(port_key))
		item.set_text(2, ports[port_key])

func _display_error(message: String):
	results_tree.clear()
	var root = results_tree.create_item()
	var error_item = results_tree.create_item(root)
	error_item.set_text(0, "ERROR")
	error_item.set_text(2, message)
	scan_button.disabled = false
	scan_button.text = "Scan"

# MissionStateから更新通知を受けた際に、現在のIPの結果を再表示
func _on_scan_results_updated(ip_address: String):
	if ip_address == ip_input.text.strip_edges():
		var scanned_ports = MissionState.get_scanned_results_for(ip_address)
		_display_results(ip_address, scanned_ports)

# ノードがシーンツリーから削除されるときに実行される
func _exit_tree():
	# MissionStateが有効であり、シグナルが接続されている場合にのみ解除する
	if is_instance_valid(MissionState) and MissionState.scan_results_updated.is_connected(_on_scan_results_updated):
		MissionState.scan_results_updated.disconnect(_on_scan_results_updated)
		# print("PortScannerUI: Disconnected from MissionState.") # デバッグ用
