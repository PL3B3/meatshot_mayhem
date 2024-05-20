extends Object
class_name TickAwareQueue

const VALID := true

var target_size_: int
var max_size_: int

var items_: Array[QueueItem] = []

var queue_size_stat_: Statistics
var queue_name_
var latest_popped_tick_: int = -1
var is_buffering_: bool = true

func _init(
		queue_name: String,
		target_size: int = 3, 
		max_size: int = 6):
	assert(target_size > 0)
	queue_name_ = queue_name
	queue_size_stat_ = LogsAndMetrics.add_universal_stat("%s-size" % queue_name, 30)
	target_size_ = target_size
	max_size_ = max_size

func push(value, tick):
	queue_size_stat_.add_sample(items_.size())
	var item = QueueItem.new(value, VALID, tick)
	__shrink_queue_if_over_max_size()
	__insert_item_in_order(item)

func pop() -> QueueItem:
	queue_size_stat_.add_sample(items_.size())
	__enable_buffering_if_empty()
	if __check_if_still_buffering():
		return QueueItem.DUMMY_ITEM
	else:
		latest_popped_tick_ = items_[0].tick()
		return items_.pop_front()

func __enable_buffering_if_empty() -> bool:
	if items_.is_empty():
		print("Tried to pop from empty queue %s. Returning dummy items until %d valid items are buffered" % [
			queue_name_, target_size_])
		is_buffering_ = true
		return true
	else:
		return false

func __check_if_still_buffering():
	if is_buffering_ and items_.size() < target_size_:
		print("Currently at %d items, buffering until %d items" % [
			items_.size(), target_size_])
	else:
		is_buffering_ = false
	return is_buffering_

func __shrink_queue_if_over_max_size():
	if items_.size() >= max_size_:
		print("Queue %s has more than %d items, discarding oldest items until size reaches %d" % [
			queue_name_, max_size_, target_size_])
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
