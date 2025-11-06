extends Control

@onready var sidebar_container = $SidebarContainer
#@onready var handle_button = $HandleButton

# サイドバーの幅
const SIDEBAR_WIDTH = Global.SIDEBAR_WIDTH
# アニメーション時間
const TWEEN_DURATION = Global.TWEEN_DURATION

# 現在の状態
var is_open = false

# 閉じた状態のX座標（画面外）
const CLOSED_X = -SIDEBAR_WIDTH
# 開いた状態のX座標（画面内）
const OPENED_X = 0

# 現在実行中のTweenを保持するための変数
var current_tween: Tween = null

# ノードがReadyになったときに初期位置を設定
func _ready():
	sidebar_container.position.x = CLOSED_X
	sidebar_container.size.x = SIDEBAR_WIDTH

# 外部から呼び出すための新しい開閉関数を定義
func toggle_sidebar() -> bool:
	# 既存の_on_handle_button_pressed()の中身をここに移す
	is_open = not is_open
	
	if current_tween != null and current_tween.is_running():
		current_tween.kill()

	var tween = create_tween()
	current_tween = tween
	
	var target_x = OPENED_X if is_open else CLOSED_X
	
	# positionプロパティを目標座標までアニメーションさせる
	tween.tween_property($SidebarContainer, "position", Vector2(target_x, $SidebarContainer.position.y), TWEEN_DURATION)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
		
	tween.tween_callback(func(): current_tween = null)
	
	return is_open
