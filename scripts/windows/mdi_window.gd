# MDIWindow.gd
extends Window

# 外部から設定される変数
var ui_scene: PackedScene

# ウィンドウの初期化
func initialize(title_text: String, content_scene: PackedScene):
	title = title_text
	ui_scene = content_scene

	#min_size = Vector2(450, 500)
	min_size = Vector2(225, 250)
	
	# ウィンドウの内容をインスタンス化して配置
	var content_instance = ui_scene.instantiate()
	$ContentContainer.add_child(content_instance)
	
	# アンカーを設定してContentContainer全体に広げる
	content_instance.set_anchors_preset(Control.PRESET_FULL_RECT)

	# オフセット（マージンに相当)をゼロに設定することで、親の端にみっちゃくさせる
	#content_instance.set_offset(0,0,0,0)	
	
	# ウィンドウの初期サイズを設定
	size = Vector2(400, 250)
	
	# 閉じるボタンのシグナル接続
	close_requested.connect(_on_close_requested)

func _on_close_requested():
	# ウィンドウが閉じられたら、ノードツリーから削除
	queue_free()
