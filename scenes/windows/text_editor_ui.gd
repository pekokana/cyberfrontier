# text_editor_ui.gd

extends Control

@onready var content_text_edit = $ContentTextEdit

var file_path: String

# 外部からファイル内容をロードするための関数
func load_content(path: String, content: String):
	file_path = path
	content_text_edit.text = content
	
	# 簡単のため、読み取り専用に設定
	content_text_edit.editable = false
