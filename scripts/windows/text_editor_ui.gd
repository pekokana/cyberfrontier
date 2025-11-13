# text_editor_ui.gd

extends Control

# VFSへの参照はAutoLoadから取得
var vfs_core = VFSCore # VFSCore AutoLoadが利用可能であることを前提とする

@onready var content_text_edit = $VBoxContainer/ContentTextEdit
@onready var file_name_label = $VBoxContainer/TopBar/FileNameLabel
@onready var save_button = $VBoxContainer/TopBar/SaveButton

var file_path: String

func _ready():
	# SaveButtonのシグナルを接続
	save_button.pressed.connect(_on_save_button_pressed)

# 外部からファイル内容をロードするための関数
func load_content(path: String, content: String):
	file_path = path
	file_name_label.text = file_path # ファイル名をUIに表示
	content_text_edit.text = content
	
	# 💡【重要】編集を可能にする
	content_text_edit.editable = true

# 保存ボタンが押されたときの処理
func _on_save_button_pressed():
	if file_path.is_empty():
		printerr("Error: File path is empty. Cannot save.")
		return

	var new_content = content_text_edit.text
	
	# 💡 VFSCoreに保存処理を依頼する
	var success = vfs_core.save_file_content(file_path, new_content)
	
	if success:
		print("File saved successfully: ", file_path)
		# 保存が完了したことをユーザーにフィードバック
		save_button.text = "Saved!"
		save_button.disabled = true
		await get_tree().create_timer(1.0).timeout
		save_button.text = "Save"
		save_button.disabled = false
	else:
		printerr("Error saving file: ", file_path)
		save_button.text = "Error!"
		save_button.disabled = true
		await get_tree().create_timer(1.0).timeout
		save_button.text = "Save"
		save_button.disabled = false

# テキストが変更されたときに保存ボタンを有効にする
func _on_content_text_edit_text_changed():
	# エディタのTextEditノードの 'text_changed' シグナルをこの関数に接続してください。
	save_button.disabled = false # 変更があれば保存可能にする
