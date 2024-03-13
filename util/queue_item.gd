extends Object
class_name QueueItem

static var DUMMY_ITEM: QueueItem = QueueItem.new(null, false)

var value_
var is_valid_: bool

func _init(value, is_valid: bool):
	value_ = value
	is_valid_ = is_valid

func is_valid():
	return is_valid_

func value():
	return value_
