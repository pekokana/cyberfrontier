extends RefCounted

var console  # TerminalUI からセットされます

var description = "Scans the local network and lists found devices."

# 非同期で実行
func execute_async(args: Array) -> void:
	var deep = "--deep" in args
	console._print("[+] Scanning network" + (" (deep mode)" if deep else "") + "...")	
	# 通常スキャン
	await console.get_tree().create_timer(1.0).timeout
	console._print(" - 192.168.56.10 found")
	await console.get_tree().create_timer(0.5).timeout
	console._print(" - 192.168.56.11 found")

	# 深いスキャン（オプション）
	if deep:
		await console.get_tree().create_timer(1.0).timeout
		console._print(" - 192.168.56.12 found (deep scan)")
		await console.get_tree().create_timer(0.5).timeout
		console._print(" - 192.168.56.13 found (deep scan)")		

	console._print("Scan complete.")
