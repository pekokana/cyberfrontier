## res://scripts/services/FTPServer.gd
extends BaseServer
class_name FTPServer

# FTPセッションの状態を保持する辞書
# Key: source_ip, Value: { "logged_in": bool, "current_dir": String }
var active_sessions: Dictionary = {}
var root_path: String = "/"

func _setup_service_specifics():
	root_path = config.get("root_path", "/")
	print("FTPServer: Root path set to %s" % root_path)

func handle_connection(source_ip: String, target_ip: String, data: Dictionary) -> Variant:
	if not active_sessions.has(source_ip):
		# 新しいセッション
		active_sessions[source_ip] = { "logged_in": false, "current_dir": root_path }
		# 最初の接続メッセージ
		return "220 Virtual FTP Server ready (bound to %s)" % bind_ip

	var command = data.get("command", "").to_upper()
	var args = data.get("args", [])
	var session = active_sessions[source_ip]

	match command:
		"USER":
			if args.size() == 1 and args[0] == config.get("username"):
				return "331 Username okay, need password."
			else:
				return "530 Not logged in."
		"PASS":
			if session.logged_in:
				return "230 User logged in, proceed."
			if args.size() == 1 and args[0] == config.get("password"):
				session.logged_in = true
				return "230 User logged in, proceed."
			else:
				return "530 Not logged in. (Wrong password)"
		"QUIT":
			active_sessions.erase(source_ip)
			return "221 Goodbye."
		"LIST":
			if not session.logged_in:
				return "530 Not logged in."
			
			var path_to_list = session.current_dir
			if args.size() > 0:
				path_to_list = vfs_core.resolve_path(args[0], session.current_dir)
			
			# VFSCoreと連携してディレクトリ内容を取得
			var contents = vfs_core.get_directory_contents_list(path_to_list)
			if contents == null:
				return "550 Failed to list directory."
				
			return "200 PORT command successful.\n150 Here comes the directory listing.\n%s\n226 Directory send OK." % contents
			
		"CWD":
			if not session.logged_in: return "530 Not logged in."
			
			if args.size() == 1:
				var new_path = vfs_core.resolve_path(args[0], session.current_dir)
				if vfs_core.node_exists(new_path) and vfs_core.get_node_by_path(new_path).type == 0: # 0: DIR
					session.current_dir = new_path
					return "250 Directory successfully changed."
			return "550 Failed to change directory."

		# RETR (ファイル取得) - 簡略化
		"RETR":
			if not session.logged_in: return "530 Not logged in."
			if args.size() == 1:
				var file_path = vfs_core.resolve_path(args[0], session.current_dir)
				var content = vfs_core.read_file(file_path)
				
				if not content.begins_with("Error:"):
					# データ通信をシミュレート
					return "150 Opening data connection.\n(Transferring: %s)\n226 Transfer complete." % content
				else:
					return "550 File not found or failed to open."
			return "500 Syntax error."

		_:
			return "502 Command not implemented."
