extends RefCounted
class_name RefillingQueue

const IS_LOGGING_ENABLED := false

var is_return_last_valid_: bool = false
var target_size_: int
var max_size_: int

var items_: Array[QueueItem] = []
var last_valid_item_: QueueItem = null
var queue_size_stat_: Statistics
var queue_name_

"""
Simple message buffer, used as safety against network variance
We want the queue as small as possible to minimize latency while ensuring we 
always have a message to pop. 
Aims to keep the # of messages in queue around some target size
Assumes we'll push and pop at roughly equal rates
How it works:
- If queue gets too few pushes, we go to size 0, then refill with dummy messages
- If too many pushes, we just drop the oldest (front) entries
"""

func _init(
		queue_name: String,
		is_return_last_valid: bool = false, 
		target_size: int = 3, 
		max_size: int = 6):
	queue_name_ = queue_name
	queue_size_stat_ = LogsAndMetrics.add_universal_stat("%s-size" % queue_name, 10)
	is_return_last_valid_ = is_return_last_valid
	target_size_ = target_size
	max_size_ = max_size

func push(item):
	queue_size_stat_.add_sample(items_.size())
	items_.push_back(QueueItem.new(item, true))
	last_valid_item_ = items_.back()
	if items_.size() > max_size_:
		__log(
			"Queue %s has more than %d items, discarding oldest items until size reaches %d",
			[queue_name_, max_size_, target_size_])
		while items_.size() > target_size_:
			items_.pop_front()

func pop() -> QueueItem:
	queue_size_stat_.add_sample(items_.size())
	if items_.is_empty():
		__log(
			"Attempting to pop from empty queue %s. Padding with %d dummy items", 
			[queue_name_, target_size_])
		for i in range(target_size_):
			items_.push_back(QueueItem.DUMMY_ITEM)
	var front_item: QueueItem = items_.pop_front()
	return last_valid_item_ if _should_return_last_valid(front_item) else front_item

func clear_items() -> void:
	items_.clear()
	last_valid_item_ = null

func _should_return_last_valid(front_item: QueueItem) -> bool:
	return !front_item.is_valid() and is_return_last_valid_ and last_valid_item_ != null

func __log(format_string: String, args: Array[Variant] = []) -> void:
	if IS_LOGGING_ENABLED:
		print(format_string % args)
