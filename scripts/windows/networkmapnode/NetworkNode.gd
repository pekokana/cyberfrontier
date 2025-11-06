# NetworkNode.gd
class_name NetworkNode extends RefCounted

# ノードの状態を定義
enum Status { UNKNOWN, SCANNED, VULNERABLE, COMPROMISED, PATCHED }

var ip_address: String
var node_name: String
var node_type: String      # "WEB", "DB", "FIREWALL"など
var position: Vector2      # マップ上の座標
var vulnerability_id: int  # 脆弱性のID (0: 安全, 1以上: 脆弱性あり)
var status: Status = Status.UNKNOWN
