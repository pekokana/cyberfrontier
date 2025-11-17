# packet_capture_ui.gd
extends Control

@onready var filter_line_edit = $VBoxContainer/HBoxFilter/FilterLineEdit
@onready var packet_list_text_edit = $VBoxContainer/PacketListTextEdit

# パケットデータの全体 (フィルタリング前のオリジナルデータ)
var original_packet_data: String = ""

# 外部からファイル内容をロードするための関数
func load_pcap_data(pcap_content: String):
	# 💡 VFSからロードされるのは、既に生成された「pcapファイルの内容」です。
	original_packet_data = pcap_content
	packet_list_text_edit.text = original_packet_data
	
	# 初回描画時にフィルタリングロジックを適用
	_on_filter_line_edit_text_changed(filter_line_edit.text)

# フィルタリング処理の実行
func _on_filter_line_edit_text_changed(new_text: String):
	var filter = new_text.strip_edges().to_lower()
	
	if filter.is_empty():
		# フィルタが空の場合は全件表示
		packet_list_text_edit.text = original_packet_data
		return

	var lines = original_packet_data.split("\n", false)
	var filtered_lines = []
	
	# 簡易フィルタリングロジック: フィルタ文字列を含む行を抽出
	for line in lines:
		if line.to_lower().find(filter) != -1:
			filtered_lines.append(line)
			
	# 結果をTextEditに表示 (Godot 3.x 対応の join)
	packet_list_text_edit.text = "\n".join(filtered_lines)
	
# 💡 デバッグ用: _ready() でフィルタリングシグナルを接続
func _ready():
	filter_line_edit.text_changed.connect(_on_filter_line_edit_text_changed)
