extends HBoxContainer

onready var name_label := $NameLabel
onready var status_label := $StatusLabel
onready var score_label := $ScoreLabel

var status := "" setget set_status
var score := 0 setget set_score

func initialize(_name, _status = "Connecting...", _score = 0):
	name_label.text = _name
	self.status = _status
	self.score = _score

func set_status(_status):
	status = _status
	status_label.text = status

func set_score(_score):
	score = _score
	if score == 0:
		score_label.text = ""
	else:
		score_label.text = str(score)
