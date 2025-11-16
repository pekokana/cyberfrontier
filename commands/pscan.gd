# PortScanCommand.gd
extends RefCounted

# description: TerminalUI.gd のインスタンス（Control型）が代入されます。
# PortScanCommand.gd のインスタンスが RefCounted のため、明示的な宣言が必要です。
var console: Control

# help コマンド用の概要説明文
var description: String = "Scans a target IP address for open ports and services."

# 💡【非同期関数】コマンドを非同期で実行します。
func execute_async(args: Array[String]) -> void:
	# 1. 引数チェック
	if args.size() < 1:
		console._print("Usage: pscan <target_ip>", console.OutputType.SYSTEM) 
		return

	var target_ip = args[0]
	
	# MissionState AutoLoadから正解データと状態を取得
	# MissionExecutionUI.gdで data.get("network", {}) が代入されている前提です。
	var network_data = MissionState.mission_network_data.get("scan_data", {})
	var target_server = network_data.get(target_ip)
	
	# ターゲットが存在しない場合の処理
	if not target_server:
		console._print("Host not found or not in scope: " + target_ip, console.OutputType.SYSTEM)
		return

	# 2. スキャン開始メッセージ
	console._print("Scanning " + target_ip + " (" + target_server.name + ")...", console.OutputType.SYSTEM)
	
	var discovered_ports = {}
	
	# 3. 非同期処理：スキャン開始のシミュレーション遅延 (例: 1.5秒)
	await console.get_tree().create_timer(1.5).timeout
	
	var ports_scanned = 0
	
	# 4. 結果のヘッダーを出力
	console._print("PORT\tSTATE\tSERVICE", console.OutputType.SYSTEM)

	# 5. ポートの処理と結果シミュレーション
	for port in target_server.ports:
		var service = target_server.ports[port] 
		
		# ポートごとに小さな遅延を追加
		await console.get_tree().create_timer(0.2).timeout
		
		# 💡【修正済み】ポート情報を整形して個別に出力
		var line = str(port) + "/tcp\topen\t" + service
		console._print(line, console.OutputType.SYSTEM)
		
		discovered_ports[port] = service
		ports_scanned += 1

	# 6. 状態管理への保存
	MissionState.save_scan_result(target_ip, discovered_ports)
	
	# 7. 最終結果の出力
	console._print("Scan completed. Found " + str(ports_scanned) + " open ports.", console.OutputType.SYSTEM)
