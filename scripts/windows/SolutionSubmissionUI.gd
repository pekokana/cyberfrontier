# SolutionSubmissionUI.gd
extends Control


@onready var label_description = $VBoxContainer/VBoxInput/LabelDescription
@onready var solution_input_line_edit = $VBoxContainer/VBoxInput/SolutionInputLineEdit
@onready var submit_button = $VBoxContainer/VBoxInput/HBoxContainer/SubmitButton
@onready var message_label = $VBoxContainer/VBoxInput/HBoxContainer/MessageLabel

# このUIを閉じられるように、親のMDIWindowへの参照を保持
var parent_mdi_window: Window = null 

func _ready():
	# 提出ボタンのシグナル接続
	submit_button.pressed.connect(_on_submit_button_pressed)
	# UIの初期化
	_initialize_ui()

# MissionExecutionUI.gd から MDIWindowの参照を受け取る (SolutionSubmissionUIが開かれた直後に呼び出される)
func set_parent_window(window: Window):
	parent_mdi_window = window

func _initialize_ui():
	var clear_cond = MissionState.mission_success_criteria
	var label_text = clear_cond.get("solution_label", "事象（調査結果）を入力してください:")
	label_description.text = label_text
	message_label.text = "" # 初期メッセージをクリア

func _on_submit_button_pressed():
	var submitted_solution = solution_input_line_edit.text
	
	# 1. MissionState に事象を提出し、判定結果を取得
	var is_correct = MissionState.submit_solution(submitted_solution)
	
	# 2. 結果に応じてメッセージを表示
	if is_correct:
		message_label.text = "OK 調査結果が受理されました！ミッション完了。"
		message_label.modulate = Color.GREEN
		submit_button.disabled = true
		solution_input_line_edit.editable = false
		
		# 3. (オプション) 親のMDIウィンドウを遅延させて閉じる (視覚的な確認時間を与える)
		if is_instance_valid(parent_mdi_window):
			get_tree().create_timer(3.0).timeout.connect(parent_mdi_window.queue_free)
	else:
		message_label.text = "NG 提出された事象は正しくありません。再調査が必要です。"
		message_label.modulate = Color.RED
		
	solution_input_line_edit.clear()
