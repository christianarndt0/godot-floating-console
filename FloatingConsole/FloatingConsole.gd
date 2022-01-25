extends Control


signal input_ok
signal input_err


export var CMD_HISTORY_LENGTH = 10
export var RES_HISTORY_LENGTH = 10
export var MAX_OUTPUT_LENGTH = 1000
export var RESIZE_ICON_OFFSET = Vector2(-10, 41)
export var COMMAND_PATTERN = "^CMD\\s.*"
export var WINDOW_TITLE = "Floating Console"
export var ECHO_COMMAND = true
export var INPUT_PREFIX = ">"
export var OUTPUT_PREFIX = "<"
export var MINIMIZE_TEXT = "> <"
export var EXPAND_TEXT = "< >"


enum {CMD_HISTORY, RES_HISTORY}
var _history = CMD_HISTORY

var _command_history = [""]
var _command_history_idx = 0
var _response_history = [""]
var _response_history_idx = 0

var _regex;

var _dragging = false
var _resizing = false


# public functions

func write(msg: String, add_to_history=true):
	# format input string
	var txt = " " + msg + "\n"
	if add_to_history:
		_response_history.append(msg)
		txt = OUTPUT_PREFIX + txt
	else:
		txt = INPUT_PREFIX + txt
	
	# append text
	var label = $VBoxContainer/ScrollContainer/LabelPrint
	label.text += txt
	
	# prune text
	if label.text.length() > MAX_OUTPUT_LENGTH:
		label.text = label.text.substr(MAX_OUTPUT_LENGTH / 2)
	
	# scroll down
	yield(get_tree().create_timer(0.1), "timeout")
	$VBoxContainer/ScrollContainer.set_v_scroll(1000)


func get_history_item(idx: int) -> String:
	if _history == CMD_HISTORY:
		return _command_history[idx]
	elif _history == RES_HISTORY:
		return _response_history[idx]
	else:
		return ""
	

func set_history_index(idx: int):
	# wrap to last item on any negative index
	if idx < 0:
		if _history == CMD_HISTORY:
			_command_history_idx = len(_command_history) - 1
		elif _history == RES_HISTORY:
			_response_history_idx = len(_response_history) - 1
		return
	
	# set value or wrap to 0 on index larger than current length
	if _history == CMD_HISTORY:
		if idx >= len(_command_history):
			_command_history_idx = 0
		else:
			_command_history_idx = idx
	elif _history == RES_HISTORY:
		if idx >= len(_response_history):
			_response_history_idx = 0
		else:
			_response_history_idx = idx


func get_history_index() -> int:
	if _history == CMD_HISTORY:
		return _command_history_idx
	elif _history == RES_HISTORY:
		return _response_history_idx
	else:
		return -1


# built-in functions
func _ready():
	_regex = RegEx.new()
	_regex.compile(COMMAND_PATTERN)


func _input(event):
	if event.is_action_pressed("ui_up"):
		set_history_index(get_history_index() - 1)
		$VBoxContainer/HBoxInput/LineEdit.text = get_history_item(get_history_index())
	elif event.is_action_pressed("ui_down"):
		set_history_index(get_history_index() + 1)
		$VBoxContainer/HBoxInput/LineEdit.text = get_history_item(get_history_index())
	elif event.is_action_pressed("ui_cancel"):
		set_history_index(0)
		$VBoxContainer/HBoxInput/LineEdit.text = ""
		
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


# private functions

func _parse_command(cmd: String):
	_command_history.append(cmd)
	_command_history_idx = len(_command_history)
	if _command_history_idx >= CMD_HISTORY_LENGTH:
		_command_history.remove(0)
		_command_history_idx -= 1
		
	# parse
	var result = _regex.search(cmd)
	if result:
		# emit parsed result
		emit_signal("input_ok", result.get_string())
	else:
		# echo full input
		write("INPUT ERROR: command pattern: " + COMMAND_PATTERN)
		emit_signal("input_err", cmd)


# signal callbacks

func _on_LineEdit_text_entered(new_text):
	if ECHO_COMMAND:
		write(new_text, false)
	_parse_command(new_text)
	
	$VBoxContainer/HBoxInput/LineEdit.text = ""


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
	if $VBoxContainer/HBoxHeader/Button.text == MINIMIZE_TEXT:
		# minimize console window
		$VBoxContainer/HBoxHeader/Label.size_flags_horizontal = SIZE_FILL
		$VBoxContainer/HBoxHeader/Button.text = EXPAND_TEXT
		$VBoxContainer/ScrollContainer.hide()
		$ColorRect.hide()
		$VBoxContainer/HBoxInput.hide()
	elif $VBoxContainer/HBoxHeader/Button.text == EXPAND_TEXT:
		# maximize console window
		$VBoxContainer/HBoxHeader/Label.size_flags_horizontal = SIZE_EXPAND_FILL
		$VBoxContainer/HBoxHeader/Button.text = MINIMIZE_TEXT
		$VBoxContainer/ScrollContainer.show()
		$ColorRect.show()
		$VBoxContainer/HBoxInput.show()


func _on_ButtonHist_button_up():
	if _history == CMD_HISTORY:
		_history = RES_HISTORY
		$VBoxContainer/HBoxInput/Button.text = OUTPUT_PREFIX
	elif _history == RES_HISTORY:
		_history = CMD_HISTORY
		$VBoxContainer/HBoxInput/Button.text = INPUT_PREFIX
		
	# switch focus to text input
	$VBoxContainer/HBoxInput/LineEdit.grab_focus()
