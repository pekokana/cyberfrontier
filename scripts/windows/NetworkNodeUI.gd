# NetworkNodeUI.gd (NetworkNodeUI.tscn にアタッチ)
extends Control

@onready var status_color = $StatusColor
@onready var ip_label = $IPLabel

var node_data: NetworkNode # 保持するデータ参照

func set_node_data(data: NetworkNode):
	node_data = data
	#ip_label.text = data.ip_address

	# 💡 存在チェックを追加
	if is_instance_valid(ip_label):
		ip_label.text = data.ip_address
	else:
		print("[CRITICAL ERROR] IPLabel node is missing or not initialized correctly!")
		# ここで処理を中断することで、後続の Nil エラーを防ぐ
		return

	update_visuals()

func update_visuals():
	var color: Color
	
	match node_data.status:
		NetworkNode.Status.SCANNED:
			color = Color.CYAN # スキャン済み
		NetworkNode.Status.VULNERABLE:
			color = Color.DARK_RED # 脆弱性あり
		NetworkNode.Status.COMPROMISED:
			color = Color.ORANGE_RED # 侵入済み
		NetworkNode.Status.PATCHED:
			color = Color.GREEN_YELLOW # パッチ適用済み
		_: # UNKNOWN など
			color = Color.DARK_GRAY
			
	status_color.color = color
