# NetworkMapUI.gd
extends Control

@onready var map_canvas = $MapCanvas # MapCanvasノードを参照

# 描画されたノードのIPとそのインスタンスを保持するキャッシュ
var node_instance_cache: Dictionary = {}
var connection_data: Array = [] # 接続情報を保持

func _ready():
	# サイズ変更を検知するシグナルを接続
	resized.connect(_on_resized)
	
	# MissionStateの更新シグナルを接続 (最新化の核となる部分)
	# CONNECT_DEFERRED: 描画更新が安全なタイミングで行われるように遅延実行
	if MissionState.has_signal("scan_results_updated"):
		MissionState.scan_results_updated.connect(_on_scan_results_updated, CONNECT_DEFERRED)
	
	_draw_map()

# マップを描画/更新するメイン関数
func _draw_map():
	# 既存の要素とキャッシュをクリア
	for child in map_canvas.get_children():
		child.queue_free()
	node_instance_cache.clear()

	# MissionStateからネットワークデータを取得
	var mission_net_data = MissionState.mission_network_data
	var network_data = mission_net_data.get("scan_data", {})
	connection_data = mission_net_data.get("connections", [])
	
	if network_data.is_empty():
		return

	# 1. ノード（サーバー）の描画
	for ip in network_data.keys():
		var server_data = network_data[ip]
		var scanned_ports = MissionState.get_scanned_results_for(ip)
		
		# ノードを表すボタンをインスタンス化
		var server_node = Button.new()
		server_node.name = ip 
		
		# PortScan結果の表示と名前の結合 (最新化される情報)
		var node_text = server_data.name + "\n" + ip
		if scanned_ports.size() > 0:
			var port_list = []
			for port in scanned_ports.keys():
				port_list.append(str(port))
			node_text += "\nOpen Ports: " + ",".join(port_list)
			
			# スキャン済みフィードバック
			server_node.add_theme_color_override("font_color", Color.CYAN)
		else:
			server_node.add_theme_color_override("font_color", Color.WHITE)
			
		server_node.text = node_text
		server_node.custom_minimum_size = Vector2(150, 70) 
		
		var pos = server_data.get("map_pos", [50, 50])
		server_node.position = Vector2(pos[0], pos[1])
		
		# 2. 描画キャンバスに追加
		map_canvas.add_child(server_node)
		node_instance_cache[ip] = server_node
	
	# 3. MapCanvasにNetworkMapUIへの参照を設定 (接続線描画用)
	if map_canvas.has_method("set_network_map_ui"):
		map_canvas.set_network_map_ui(self)

	# 4. 描画後にスケーリング処理を実行
	_scale_map_to_fit()
	
	# 接続線を描画するために、MapCanvasに再描画を要求します。
	map_canvas.queue_redraw()


# MissionStateからのシグナル受信時に実行
func _on_scan_results_updated(ip_address: String, ports: Dictionary):
	# スキャン結果が更新されたら、マップ全体を再描画して最新情報を反映
	print("NetworkMapUI: Received scan update for " + ip_address + ". Redrawing map.")
	_draw_map() 

# サイズ変更シグナルに応答
func _on_resized():
	call_deferred("_scale_map_to_fit")

# マップ全体を親のサイズに収めるようにスケーリングと中央配置を行う関数
func _scale_map_to_fit():
	if map_canvas.get_child_count() == 0:
		return

	# 1. すべてのノードを含むバウンディングボックスを計算 (マップの論理的な全体サイズ)
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for node in map_canvas.get_children():
		if node is Control:
			var node_rect = Rect2(node.position, node.custom_minimum_size)
			min_pos = min_pos.min(node_rect.position)
			max_pos = max_pos.max(node_rect.position + node_rect.size)

	var map_size = max_pos - min_pos
	if map_size.x <= 0 or map_size.y <= 0:
		map_size = Vector2(1, 1)

	var parent_size = size 

	# 2. スケーリングファクターを計算
	var margin = 0.9 
	var scale_x = (parent_size.x * margin) / map_size.x
	var scale_y = (parent_size.y * margin) / map_size.y
	var scale_factor = min(scale_x, scale_y)
	
	# 3. マップコンテナにスケーリングを適用
	map_canvas.scale = Vector2(scale_factor, scale_factor)
	
	# 4. 中央配置を計算
	var scaled_map_size = map_size * scale_factor
	var offset_x = (parent_size.x - scaled_map_size.x) / 2.0 - min_pos.x * scale_factor
	var offset_y = (parent_size.y - scaled_map_size.y) / 2.0 - min_pos.y * scale_factor
	
	map_canvas.position = Vector2(offset_x, offset_y)
	
	# 接続線の再描画
	map_canvas.queue_redraw()
