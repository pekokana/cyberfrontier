# VFSNode.gd
class_name VFSNode
extends RefCounted # メモリ管理のためにRefCountedを使うのが一般的

# enum定義を削除し、VFSConstantsを参照する
#const NodeType = preload("VFSConstants.gd").NodeType # 新しい定数クラスのenumを参照
# ファイルとディレクトリのタイプを定義する
enum NodeType { DIR, FILE, PCAP }

# --- プロパティ ---

var type: int # ファイルかディレクトリか (NodeType.FILE / NodeType.DIR)
var name: String # ファイル名またはディレクトリ名 (例: "auth.log", "user")
var path: String # フルパス (例: "/home/user/logs/auth.log")
var content: String = "" # ファイルの内容 (テキストミッション用)

# ディレクトリの場合、子ノードを保持する (キーはノード名)
var children: Dictionary = {} 

# --- 初期化 ---

func _init(node_name: String, node_type: int, full_path: String = "", file_content: String = ""):
	name = node_name
	type = node_type
	path = full_path
	if type == VFSNode.NodeType.FILE:
		content = file_content
