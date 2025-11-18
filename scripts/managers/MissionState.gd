# MissionState.gd (AutoLoadとして登録)
extends Node

# ミッション開始時に MissionExecutionUI から設定されるデータ
var mission_network_data: Dictionary = {}

# プレイヤーがスキャンで見つけたポート情報を保持する (スキャン結果の状態)
# 構造: { "192.168.1.100": { "22": "SSH", "8080": "HTTP" }, ... }
var scanned_results: Dictionary = {}

# 現在のミッションのクリア条件
var mission_success_criteria: Dictionary = {}
# フラグ提出タイプのミッションで必要な正解の事象/情報
var required_solution: String = ""

# 難易度に応じたヒントやメモを格納
var mission_hints: Array = []

# スキャン結果が更新されたことを通知するシグナル
signal scan_results_updated(ip_address)
# ミッションが完了したことを通知するシグナル
signal mission_completed(result_status: String)

# MissionExecutionUI.gd から呼び出され、ミッション開始時に初期化する
func initialize_mission_data(data: Dictionary):
	# MissionExecutionUI から渡されたミッションデータからネットワーク情報を抽出

	# 修正/追記: mission_network_data をJSONの'network_config'から設定する
	mission_network_data = data.get("setup", {}).get("network_config", {}) 

	# ミッションクリア条件と正解を設定
	var clear_cond = data.get("clear_condition", {})
	mission_success_criteria = clear_cond

	#JSONのキーに合わせて 'required_solution' を取得する
	#'flag_submission'だけでなく'solution_submission'タイプも対応
	if clear_cond.get("type") == "solution_submission":
		required_solution = clear_cond.get("required_solution", "").strip_edges()
	elif clear_cond.get("type") == "flag_submission":
		required_solution = clear_cond.get("flag", "").strip_edges()
	else:
		required_solution = ""

	# ヒントデータをJSONからロード
	mission_hints = data.get("hints", [])

	# 過去の結果をクリア
	scanned_results.clear()

	# =======================================================
	# VFSのクリアと初期ファイルのセットアップ
	# =======================================================
	
	# 1. VFSをリセット (VFSCoreに reset_vfs() が実装されている必要があります)
	#    VFSCoreが有効なインスタンスであるか、または存在しない場合に備える
	if is_instance_valid(VFSCore) and VFSCore.has_method("reset_vfs"):
		VFSCore.reset_vfs()
		print("DEBUG: VFSCore reset completed.")
	
	# 2. 初期ファイルをVFSにセットアップ (pcapファイル生成を含む)
	_setup_initial_files(data.get("setup", {}).get("initial_files", []), data)
	
	print("MissionState initialized with full mission data (Network, Flag, and VFS setup).")

# スキャン結果を取得する
func get_scanned_results_for(ip: String) -> Dictionary:
	return scanned_results.get(ip, {})


# pcapファイル内容を生成するヘルパー関数
func _generate_pcap_content(required_flag: String, target_ip: String) -> String:
	var output_lines = []
	
	# ダミーデータ生成用のIPリスト
	var internal_ips = ["192.168.1.1", "192.168.1.2", "192.168.1.3", "192.168.1.4"]
	var external_ips = ["203.0.113.50", "8.8.8.8"]
	
	# 💡 修正: 変数を関数のスコープ内で初期宣言する (エラー対策)
	var username = "anonymous" 
	var password = "password"

	# 認証情報を USER と PASS に分割
	var parts = required_flag.split(":", false, 2)
	
	if parts.size() == 2:
		username = parts[0].strip_edges()
		password = parts[1].strip_edges()
	
	# --- 1. 正解のFTPパケット (攻撃元 -> ターゲット) ---
	var correct_src_ip = "192.168.1.1" 
	var correct_time_user = "10:05:32"
	var correct_time_pass = "10:05:33"
	
	# USERコマンド (平文)
	output_lines.append("[%s] %s -> %s [FTP] C: USER %s" % [correct_time_user, correct_src_ip, target_ip, username])
	# PASSコマンド (平文 - フラグ)
	output_lines.append("[%s] %s -> %s [FTP] C: PASS %s" % [correct_time_pass, correct_src_ip, target_ip, password])
	# サーバーからの応答 (ログイン成功)
	output_lines.append("[%s] %s -> %s [FTP] S: 230 Login successful." % [correct_time_pass, target_ip, correct_src_ip])

	# --- 2. ダミーのFTPパケットとその他のノイズを生成 ---
	# 💡 修正: プロトコルリストに "TCP" を追加
	var protocols = ["HTTP", "DNS", "ARP", "ICMP", "SSH", "FTP", "TCP"] 
	var tcp_flags = ["S", "A", "SA", "F", "FA"] # SYN, ACK, SYN/ACK, FIN, FIN/ACK
	var ftp_commands = ["C: PWD", "C: TYPE I", "C: CWD files", "C: LIST", "C: QUIT"]
	var ftp_responses = ["S: 200 Command okay.", "S: 550 File not found.", "S: 421 Service not available."]
	var noise_count = 50 # ノイズパケットを増やして、TCPパケットの割合を上げる

	for i in range(noise_count):
		var time = "%02d:%02d:%02d" % [randi() % 24, randi() % 60, randi() % 60]
		var src = internal_ips[randi() % internal_ips.size()]
		var dst = external_ips[randi() % external_ips.size()]
		var protocol = protocols[randi() % protocols.size()]
		
		var info = ""
		match protocol:
			"HTTP": info = "GET /data.php" if randf() < 0.5 else "200 OK"
			"DNS": info = "Standard query A " + dst
			"ARP": info = "Who has " + dst + "? Tell " + src
			"ICMP": info = "Echo (ping) request"
			"SSH": info = "Encrypted packet length " + str(randi() % 100 + 50)
			"FTP": # ランダムなFTPコマンドまたはレスポンス
				if randf() < 0.5:
					info = ftp_commands[randi() % ftp_commands.size()]
				else:
					info = ftp_responses[randi() % ftp_responses.size()]
			"TCP": # 💡 追加: TCP制御パケットのダミーを生成
				var flag = tcp_flags[randi() % tcp_flags.size()]
				# ランダムなSeq/Ack番号と、ごくまれにペイロードを持つ
				var seq = randi() % 100000
				var ack = randi() % 100000
				var payload_len = 0
				if randf() < 0.1: # 10%の確率でデータを含む
					payload_len = randi() % 500 + 1
				
				info = "Flags: %s, Seq: %d, Ack: %d, Len: %d" % [flag, seq, ack, payload_len]
			
		var line = "[%s] %s -> %s [%s] %s" % [time, src, dst, protocol, info]
		output_lines.append(line)
		
	# --- 3. シャッフルしてランダムな順序にする ---
	output_lines.shuffle()
	
	return "\n".join(output_lines)

# 初期ファイルリストを処理し、VFSにデータをセットアップする関数
func _setup_initial_files(initial_files: Array, mission_data: Dictionary):
	var target_ip = mission_data.get("setup", {}).get("target_server", "")
	#var required_flag = mission_data.get("clear_condition", {}).get("flag", "")

	# required_flagではなく、インスタンス変数 required_solution を使用する
	var solution_data = required_solution

	if not is_instance_valid(VFSCore):
		printerr("FATAL ERROR: VFSCore AutoLoad is missing.")
		return
		
	for file_info in initial_files:
		var file_path = file_info.get("path", "")
		var file_type = file_info.get("type", "") # 例: "pcap", "dir", "file"
		
		if file_type.is_empty() or file_path.is_empty():
			continue

		# =======================================================
		# 1. VFSノードをまず作成する！ (内容が空でも先にノードを作成)
		# =======================================================
		# VFSCore._create_node_from_path には文字列のタイプ (file_type) を渡す
		VFSCore._create_node_from_path(file_path, file_type, "") 

		# =======================================================
		# 2. pcapノードの場合、内容を生成し、VFSに上書き保存する
		# =======================================================
		if file_type.to_lower() == "pcap":
			# pcapコンテンツを生成
			# solution_data を認証情報として渡す
			var pcap_content = _generate_pcap_content(solution_data, target_ip)			
			# VFSCoreの公開関数を使ってファイル内容を更新
			VFSCore.update_file_content(file_path, pcap_content)

# 外部（SolutionSubmissionUIなど）から提出された事象をチェックする
func submit_solution(submitted_solution: String) -> bool: # 💡 関数名を変更
	if mission_success_criteria.get("type") != "solution_submission":
		printerr("Error: Current mission is not a solution submission type.")
		return false

	var submitted = submitted_solution.strip_edges()
	var correct = required_solution # 💡 変数名を変更
	
	# 提出された事象が空の場合は不合格
	if submitted.is_empty():
		return false

	# 大文字・小文字の区別をJSON設定に基づいて行う
	var case_sensitive = mission_success_criteria.get("case_sensitive", false)
	var is_correct = false
	
	if case_sensitive:
		is_correct = (submitted == correct)
	else:
		is_correct = (submitted.to_lower() == correct.to_lower())

	if is_correct:
		print("Mission Success! Solution submitted: ", submitted)
		# シグナルでミッション完了を通知
		mission_completed.emit("success")
		return true
	else:
		print("Mission Failure: Incorrect solution submitted.")
		return false

# ヒントデータを取得するための関数
func get_mission_hints() -> Array:
	return mission_hints

# スキャン結果を保存し、UIの更新を通知する
func save_scan_result(ip_address: String, ports: Dictionary):
	# 既存のポート情報があれば結合し、なければ新規作成
	var existing_ports = scanned_results.get(ip_address, {})
	
	# 結合ロジック: 新しい結果で既存の結果を上書きする
	for port in ports.keys():
		existing_ports[port] = ports[port]
		
	scanned_results[ip_address] = existing_ports
	
	# スキャン結果が更新されたことを通知する
	scan_results_updated.emit(ip_address)
	print("DEBUG: Scan result saved and signal emitted for: ", ip_address)
