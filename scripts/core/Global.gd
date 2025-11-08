extends Node

# UI設定
## サイドバーサイズ
const SIDEBAR_WIDTH = 100.0
const TWEEN_DURATION = 0.5

# ----------
# ヘルパーメソッド
# ----------

#💡 実行中のノードツリー全体を出力するヘルパー関数
func print_node_tree(node: Node, indent: int = 0) -> void:
	# インデントを作成
	var prefix = ""
	for i in range(indent):
		prefix += "  "
	
	var type_name = node.get_class()
	var line = prefix + "|-- " + node.name + " (" + type_name + ")"
	
	# スクリプトがアタッチされている場合はそのパスも表示
	var script = node.get_script()
	if script != null:
		line += " [Script]" # 詳細なパスは長くなるため[Script]のみ
		
	print(line)

# 💡 追加: スクリプトに定義されているメソッド一覧を出力
	if script != null and script is Script:
		var method_list = script.get_script_method_list()
		if not method_list.is_empty():
			var methods_str = []
			for method in method_list:
				# 辞書の'name'キーから関数名を取得
				methods_str.append(method.name)
			
			# メソッドリストを整形して出力
			# 組み込み関数（_readyなど）は除外されないため、全て出力されます。
			print(prefix + "  |-> Methods: [" + ", ".join(methods_str) + "]")

	# 子ノードを再帰的に処理
	for child in node.get_children():
		print_node_tree(child, indent + 1)
