extends Object
class_name TickAwareQueue

const VALID := true
const IS_LOGGING_ENABLED := false
static var NO_DEFAULT_VALUE = null

var target_size_: int
var max_size_: int
var default_return_value_if_empty_: Variant
var items_: Array[QueueItem] = []

var queue_size_at_pop_stat_: Statistics
var queue_size_at_push_stat_: Statistics
var queue_name_
var latest_popped_tick_: int = -1
var is_buffering_: bool = true

func _init(
		queue_name: String,
		default_return_value_if_empty: Variant = NO_DEFAULT_VALUE,
		target_size: int = 3, 
		max_size: int = 6):
	assert(target_size > 0)
	queue_name_ = queue_name
	queue_size_at_pop_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-pop" % queue_name, 60)
	queue_size_at_push_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-push" % queue_name, 60)
	default_return_value_if_empty_ = default_return_value_if_empty
	target_size_ = target_size
	max_size_ = max_size

func push(value, tick):
	queue_size_at_push_stat_.add_sample(items_.size())
	var item = QueueItem.new(value, VALID, tick)
	__shrink_queue_if_over_max_size()
	__insert_item_in_order(item)

func pop() -> QueueItem:
	queue_size_at_pop_stat_.add_sample(items_.size())
	__enable_buffering_if_empty()
	if __check_if_still_buffering():
		return __get_default_if_configured_else_dummy()
	else:
		latest_popped_tick_ = items_[0].tick()
		return items_.pop_front()

func __enable_buffering_if_empty() -> bool:
	if items_.is_empty():
		__log("Tried to pop from empty queue %s. Returning dummy items until %d valid items are buffered", [
			queue_name_, target_size_])
		is_buffering_ = true
		return true
	else:
		return false

func __check_if_still_buffering():
	if is_buffering_ and items_.size() < target_size_:
		__log("Currently at %d items, buffering until %d items", [items_.size(), target_size_])
	else:
		is_buffering_ = false
	return is_buffering_

func __shrink_queue_if_over_max_size():
	if items_.size() >= max_size_:
		__log(
			"Queue %s has more than %d items, discarding oldest items until size reaches %d", 
			[queue_name_, max_size_, target_size_])
		while items_.size() > target_size_:
			items_.pop_front()

func __insert_item_in_order(item: QueueItem):
	if item.tick() <= latest_popped_tick_:
		return
	for i in items_.size():
		if items_[i].tick() > item.tick():
			items_.insert(i, item)
			return
		elif items_[i].tick() == item.tick():
			items_[i] = item
			return
	# item's tick is highest seen so far, so append to end of buffer
	items_.push_back(item)

func __get_default_if_configured_else_dummy():
	if default_return_value_if_empty_ == NO_DEFAULT_VALUE:
		return QueueItem.DUMMY_ITEM
	else:
		return QueueItem.new(default_return_value_if_empty_, VALID, Network.NO_TICK)

func __log(format_string: String, args: Array[Variant] = []) -> void:
	if IS_LOGGING_ENABLED:
		print(format_string % args)