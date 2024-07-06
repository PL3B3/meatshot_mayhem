extends RefCounted
class_name QueueItem

const NO_TICK = -1
static var DUMMY_ITEM: QueueItem = QueueItem.new(null, false)
static var SORT_BY_TICK: Callable = QueueItem.sort_by_tick

var value_
var is_valid_: bool
var tick_: int

func _init(value, is_valid:bool, tick:int=NO_TICK):
	value_ = value
	is_valid_ = is_valid
	tick_ = tick

func is_valid():
	return is_valid_

func value():
	return value_

func tick():
	return tick_

static func sort_by_tick(left: QueueItem, right: QueueItem):
	return left.tick() < right.tick()
