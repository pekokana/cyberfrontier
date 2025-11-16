# MapCanvas.gd
extends Control # MapCanvasがControlノードであることを想定

# 親のNetworkMapUIへの参照 (接続データとノード位置を取得するため)
var network_map_ui: Control 

# NetworkMapUIから参照を設定するためのメソッド
func set_network_map_ui(ui_instance: Control):
	network_map_ui = ui_instance

# Godotの描画関数。queue_redraw()が呼び出されると実行される。
func _draw():
	# 参照が有効か確認
	if not is_instance_valid(network_map_ui):
		return
		
	# NetworkMapUIからデータとキャッシュを取得
	var connection_data = network_map_ui.connection_data
	var node_cache = network_map_ui.node_instance_cache
	
	var line_color = Color(0.3, 0.7, 0.9, 0.5) # 青系の半透明
	var line_thickness = 2.0 

	# 接続線の描画
	for conn in connection_data:
		var from_node = node_cache.get(conn.from)
		var to_node = node_cache.get(conn.to)
		
		if is_instance_valid(from_node) and is_instance_valid(to_node):
			# 接続線の始点と終点を計算
			# ノードの中心座標を使用 (位置 + サイズ/2)
			var from_center = from_node.position + (from_node.custom_minimum_size / 2)
			var to_center = to_node.position + (to_node.custom_minimum_size / 2)
			
			# MapCanvasのローカル座標で線を描画
			draw_line(from_center, to_center, line_color, line_thickness)
