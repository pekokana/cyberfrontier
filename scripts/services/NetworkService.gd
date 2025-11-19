## res://scripts/services/NetworkService.gd
extends Node
class_name NetworkService

# VirtualHostへの参照をプリロード
const VirtualHost = preload("res://scripts/services/VirtualHost.gd")

# Key: Host ID, Value: VirtualHostのインスタンス
var virtual_hosts: Dictionary = {}

# Key: IPアドレス, Value: Host ID (IPからホストを一意に特定するためのマップ)
var ip_to_host_id: Dictionary = {}

# ==============================================================================
# ミッションロード
# ==============================================================================

# mission_configs: mission.json の "virtual_hosts" 部分
# vfs_core: MissionStateから渡されるVFSCoreのインスタンス
func load_virtual_hosts(mission_configs: Dictionary, vfs_core: Object):
	# クリア処理
	virtual_hosts.clear()
	ip_to_host_id.clear()
	
	if mission_configs.is_empty():
		print("NetworkService: No virtual hosts defined in mission.")
		return
		
	for host_id in mission_configs.keys():
		var host_config = mission_configs[host_id]
		
		var host_instance = VirtualHost.new()
		host_instance.initialize(host_id, host_config, vfs_core) # VirtualHostを初期化
		
		virtual_hosts[host_id] = host_instance
		
		# IPアドレスとホストIDのマッピングを作成
		for ip in host_config.ip_addresses:
			ip_to_host_id[ip] = host_id
			print("NetworkService: Mapped IP %s to Host %s" % [ip, host_id])


# ==============================================================================
# ネットワーク通信ルーティング
# ==============================================================================

# クライアントコマンドが通信を試みるメインAPI
# source_ip: クライアント側のIPアドレス (例: 192.168.1.1)
# target_ip: 接続先のIPアドレス (NIC)
# target_port: 接続先のポート番号
func route_connection(source_ip: String, target_ip: String, protocol: String, target_port: int, data: Dictionary) -> Variant:
	if not ip_to_host_id.has(target_ip):
		return "Host %s is unreachable or connection timed out." % target_ip
		
	var host_id = ip_to_host_id[target_ip]
	var host_instance = virtual_hosts[host_id]
	
	# VirtualHostのhandle_connectionに処理を委譲 (IPバインドチェックはVirtualHost内で行われる)
	return host_instance.handle_connection(source_ip, target_ip, protocol, target_port, data)
