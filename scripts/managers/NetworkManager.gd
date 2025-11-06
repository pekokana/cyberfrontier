# NetworkManager.gd
extends Node2D 

# 外部シーンとクラスの参照
# NetworkNode.gd は class_name NetworkNode で定義済みのため、プリロード不要
const NODE_UI_SCENE = preload("res://scenes/windows/networkmapnode/NetworkNodeUI.tscn")

# ネットワーク内の全ノードデータを保持 (IPアドレスをキーとする)
var current_nodes: Dictionary = {} 
# 描画された Line2D ノードの配列
var link_nodes: Array = [] 

## =================================================================
## 起動とロード処理
## =================================================================

# 外部JSONファイルからミッションデータをロードし、マップを生成する
# mission_file_path: JSONファイルへのパス (例: "res://data/mission_01.json")
func load_mission(mission_file_path: String):
	# 既存のノードとリンクをクリア
	_clear_map()
	
	# 1. JSONファイルの読み込みとパース
	var file = FileAccess.open(mission_file_path, FileAccess.READ)
	if not file:
		print("[ERROR] Failed to open mission file: ", mission_file_path)
		return
		
	var json_text = file.get_as_text()
	var mission_data = JSON.parse_string(json_text)

	if not mission_data:
		print("[ERROR] Failed to parse mission JSON.")
		return
	
	# 2. ノードとリンクの生成
	if mission_data.has("nodes"):
		_create_nodes(mission_data.nodes)
	if mission_data.has("links"):
		_create_links(mission_data.links)

func _clear_map():
	# 子ノードを安全に削除
	for child in get_children():
		child.queue_free()
	current_nodes.clear()
	link_nodes.clear()

## =================================================================
## マップの動的生成
## =================================================================

# ノードデータに基づいて UI インスタンスを生成し、配置する
func _create_nodes(node_list: Array):
	for data in node_list:
		# 1. データオブジェクトの作成
		var node_info = NetworkNode.new()
		node_info.ip_address = data.ip
		node_info.node_name = data.name
		node_info.node_type = data.type
		node_info.position = Vector2(data.pos_x, data.pos_y)
		node_info.vulnerability_id = data.vulnerability_id
		
		# 初期ステータスの設定 (JSONの文字列を NetworkNode.Status の Enum に変換)
		if data.has("initial_status"):
			# to_upper() で大文字に変換し、Enum のキーを検索
			var status_key = NetworkNode.Status.keys().find(data.initial_status.to_upper())
			if status_key != -1:
				node_info.status = NetworkNode.Status[data.initial_status.to_upper()]
		
		current_nodes[node_info.ip_address] = node_info
		
		# 2. UIノードのインスタンス化と設定
		var node_ui = NODE_UI_SCENE.instantiate()
		node_ui.global_position = node_info.position # ワールド座標で位置を設定
		node_ui.name = node_info.ip_address          # 検索のためにIPを名前として使う
		node_ui.set_node_data(node_info)             # データを渡して初期描画を指示
		add_child(node_ui)

# リンクデータに基づいて Line2D を描画する
func _create_links(link_list: Array):
	for link in link_list:
		var source_ip = link.source
		var target_ip = link.target
		
		# 描画対象のノードデータが存在するか確認
		if current_nodes.has(source_ip) and current_nodes.has(target_ip):
			var line = Line2D.new()
			
			# Line2Dは子ノードとして追加
			# ノードデータから位置情報を取得
			line.add_point(current_nodes[source_ip].position)
			line.add_point(current_nodes[target_ip].position)
			line.default_color = Color.GRAY
			line.width = 2.0
			add_child(line)
			link_nodes.append(line)

## =================================================================
## コマンド連携（状態更新）
## =================================================================

# 外部コマンド（scan.gdなど）から呼び出され、ノードの状態を更新する
# ip: ターゲットIPアドレス
# new_status: NetworkNode.Status のいずれかの値
func set_node_status(ip: String, new_status: NetworkNode.Status) -> bool:
	if current_nodes.has(ip):
		var node_info: NetworkNode = current_nodes[ip]
		node_info.status = new_status
		
		# 対応する UI ノードを検索し、見た目の更新を指示
		var node_ui = find_child(ip)
		if is_instance_valid(node_ui):
			node_ui.update_visuals()
			return true
	return false
