extends Control


signal input_ok
signal input_err


export var HISTORY_LENGTH = 10
export var RESIZE_ICON_OFFSET = Vector2(-10, 41)
export var COMMAND_PATTERN = "^CMD\\s.*"
export var WINDOW_TITLE = "Floating Console"
export var ECHO_COMMAND = true


var _regex;

var _command_history = [""]
var _command_history_idx = 0

var _dragging = false
var _resizing = false


func _ready():
	_regex = RegEx.new()
	_regex.compile(COMMAND_PATTERN)


func write(txt: String):
	$VBoxContainer/ScrollContainer/LabelPrint.text += txt + "\n"
	yield(get_tree().create_timer(0.1), "timeout")
	$VBoxContainer/ScrollContainer.set_v_scroll(1000)


func _parse_command(cmd: String):
	_command_history.append(cmd)
	_command_history_idx = len(_command_history)
	if _command_history_idx >= HISTORY_LENGTH:
		_command_history.remove(0)
		_command_history_idx -= 1
		
	# parse
	var result = _regex.search(cmd)
	if result:
		# emit parsed result
		emit_signal("input_ok", result.get_string())
	else:
		# echo full input
		write("< INPUT ERROR: command pattern: " + COMMAND_PATTERN)
		emit_signal("input_err", cmd)


func _on_LineEdit_text_entered(new_text):
	if ECHO_COMMAND:
		write("> " + new_text)
	_parse_command(new_text)
	
	$VBoxContainer/HBoxInput/LineEdit.text = ""
	

func _input(event):
	var load_from_history = false
	
	if event.is_action_pressed("ui_up"):
		_command_history_idx -= 1
		load_from_history = true
	elif event.is_action_pressed("ui_down"):
		_command_history_idx += 1
		load_from_history = true
	elif event.is_action_pressed("ui_cancel"):
		_command_history_idx = 0
		$VBoxContainer/HBoxInput/LineEdit.text = ""
		
	if load_from_history:
		if _command_history_idx < 0:
			_command_history_idx = len(_command_history) - 1
		elif _command_history_idx > len(_command_history) - 1:
			_command_history_idx = 0
		$VBoxContainer/HBoxInput/LineEdit.text = _command_history[_command_history_idx]
		
	# move or resize console window
	if _dragging:
		if event is InputEventMouseMotion:
			set_position(rect_position + event.relative)
	elif _resizing:
		if event is InputEventMouseMotion:
			rect_size += event.relative
			$ColorRect.rect_position = rect_size + RESIZE_ICON_OFFSET
			$VBoxContainer.rect_size = rect_size
			$VBoxContainer/ScrollContainer.rect_min_size.y = rect_size.y


func _on_LabelHeader_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			_dragging = true
		else:
			_dragging = false


func _on_ColorRect_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			_resizing = true
		else:
			_resizing = false


func _on_ButtonMin_button_up():
	if $VBoxContainer/HBoxHeader/Button.text == "> <":
		# minimize console window
		$VBoxContainer/HBoxHeader/Label.size_flags_horizontal = SIZE_FILL
		$VBoxContainer/HBoxHeader/Button.text = "< >"
		$VBoxContainer/ScrollContainer.hide()
		$ColorRect.hide()
		$VBoxContainer/HBoxInput.hide()
	elif $VBoxContainer/HBoxHeader/Button.text == "< >":
		# maximize console window
		$VBoxContainer/HBoxHeader/Label.size_flags_horizontal = SIZE_EXPAND_FILL
		$VBoxContainer/HBoxHeader/Button.text = "> <"
		$VBoxContainer/ScrollContainer.show()
		$ColorRect.show()
		$VBoxContainer/HBoxInput.show()
