## res://scripts/services/BaseServer.gd
extends RefCounted
class_name BaseServer

var service_type: String = "" 
var service_port: int = 0
var config: Dictionary = {} 
var vfs_core: Object
var bind_ip: String = "0.0.0.0"

# サービスの初期化関数
func initialize_service(type: String, port: int, service_config: Dictionary, vfs: Object, b_ip: String):
	self.service_type = type
	self.service_port = port
	self.config = service_config
	self.vfs_core = vfs
	self.bind_ip = b_ip 
	_setup_service_specifics()

# サービス固有のセットアップ (オーバーライドを想定)
func _setup_service_specifics():
	pass

# 通信処理のメイン関数 (オーバーライド必須)
# source_ip: 接続元 (クライアント) IP
# target_ip: 接続先 (サーバー/NIC) IP
func handle_connection(source_ip: String, target_ip: String, data: Dictionary) -> Variant:
	printerr("ERROR: BaseServer.handle_connection() must be overridden in child class.")
	return "501 Protocol Not Implemented."
