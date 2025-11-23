## res://scripts/services/VirtualHost.gd
extends RefCounted
class_name VirtualHost

# 💡 NetworkServiceから参照できるように、サービス実装クラスを定義
const FTPServer = preload("res://scripts/services/FTPServer.gd")
const WebServer = preload("res://scripts/services/WebServer.gd")
const DBServer = preload("res://scripts/services/DBServer.gd")
const APPServer = preload("res://scripts/services/AppServer.gd")

const SERVER_CLASSES = {
	"ftp": FTPServer,
	"web": WebServer,
	"db": DBServer,
	"ap": APPServer,
	#"ftp": FTPServer,
	# "web": WebServer, ... (他サービスもここに追加)
}

var host_id: String
@export var ip_addresses = []
# Key: bind_ip_port_protocol (例: "10.0.0.10_21_ftp", "0.0.0.0_80_web"), Value: BaseServerインスタンス
var services: Dictionary = {} 

var vfs_core: Object # VFSCoreへの参照

# ホストの初期化
func initialize(id: String, host_config: Dictionary, vfs: Object):
	self.host_id = id
	self.ip_addresses = host_config.get("ip_addresses", [])
	self.vfs_core = vfs
	
	_load_services(host_config.get("services", []))
	print("VirtualHost %s: Initialized with IPs: %s" % [host_id, ip_addresses])

# サービス（サーバー機能）のロード
func _load_services(service_configs: Array):
	for service_data in service_configs:
		var type = service_data.get("type", "unknown")
		var port = service_data.get("port", 0)
		var config = service_data.get("config", {})
		var bind_ip = service_data.get("bind_ip", "0.0.0.0")
		
		if SERVER_CLASSES.has(type):
			var service_class = SERVER_CLASSES[type]
			var service_instance = service_class.new()
			
			if service_instance.has_method("initialize_service"):
				# BaseServerの初期化を呼び出す (bind_ipを渡す)
				service_instance.initialize_service(type, port, config, vfs_core, bind_ip) 
				
				# 💡 サービス辞書のキーを (bind_ip_port_protocol) の形式で格納
				var key = "%s_%d_%s" % [bind_ip, port, type]
				services[key] = service_instance
				print("VirtualHost %s: Loaded service %s on %s:%d" % [host_id, type.to_upper(), bind_ip, port])
			else:
				printerr("VirtualHost %s: Service %s does not have initialize_service method." % [host_id, type])

# 通信の処理 (クライアントコマンドから呼ばれる)
func handle_connection(source_ip: String, target_ip: String, protocol: String, target_port: int, data: Dictionary) -> Variant:
	
	# 1. 完全一致 (特定のNICにバインドされているかチェック)
	var specific_key = "%s_%d_%s" % [target_ip, target_port, protocol]
	if services.has(specific_key):
		return services[specific_key].handle_connection(source_ip, target_ip, data)
		
	# 2. ワイルドカード一致 (0.0.0.0にバインドされているかチェック)
	var wildcard_key = "0.0.0.0_%d_%s" % [target_port, protocol]
	if services.has(wildcard_key):
		# サービスインスタンスに処理を委譲 (0.0.0.0バインドのサービスが応答)
		return services[wildcard_key].handle_connection(source_ip, target_ip, data)

	# 3. サービスが見つからない場合
	# HTTPエラー形式で応答を返す
	if protocol == "web":
		return {"status": 400, "headers": {"Content-Type": "text/plain"}, "body": "Web service not found on %s:%d" % [target_ip, target_port]}

	return "503 Service Unavailable on %s:%d" % [target_ip, target_port]

	## 3. どちらも見つからない
	#return "Connection refused: Host is blocking %s traffic on %s:%d (Service not bound to this interface)." % [protocol.to_upper(), target_ip, target_port]
