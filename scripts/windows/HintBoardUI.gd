# HintBoardUI.gd
extends Control

@onready var content_vbox = $VBoxContainer/ScrollContainer/ContentVBox

func _ready():
	# 実際は MissionState.gd (AutoLoad) を直接使用します
	_display_hints()

func _display_hints():
	# MissionState (AutoLoad) からヒントデータを取得
	var hints = MissionState.get_mission_hints() 
	
	# 既存のノードをクリア
	for child in content_vbox.get_children():
		child.queue_free()
		
	if hints.is_empty():
		var label = Label.new()
		label.text = "現在、利用可能な情報やメモはありません。"
		content_vbox.add_child(label)
		return

	# ヒントを順に表示
	for hint_data in hints:
		var type = hint_data.get("type", "note")
		var content = hint_data.get("content", "コンテンツが見つかりません。")
		
		var label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		var prefix = ""
		var color = Color.WHITE
		
		match type:
			"objective":
				prefix = "🎯 [ミッション目標]: "
				color = Color("#7FFF00") # YellowGreen
			"hint":
				prefix = "💡 [ヒント]: "
				color = Color("#40E0D0") # Turquoise
			"note":
				prefix = "📝 [メモ]: "
				color = Color("#F0F8FF") # AliceBlue
			"noise":
				prefix = "📝[メモ]: "
				color = Color("#FF6347") # Tomato (惑わす情報/ノイズ)
		
		label.text = prefix + content
		label.add_theme_color_override("font_color", color)
		
		content_vbox.add_child(label)
