extends Object
class_name RefillingQueue

const NO_STAT_NAME = ""

var is_return_last_valid_: bool = false
var target_size_: int
var max_size_: int

var items_: Array[QueueItem] = []
var last_valid_item_: QueueItem = null
var queue_size_stat_: Statistics

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
		is_return_last_valid: bool = false, 
		stat_name: String = "", 
		target_size: int = 2, 
		max_size: int = 4):
	is_return_last_valid_ = is_return_last_valid
	target_size_ = target_size
	max_size_ = max_size
	if stat_name != NO_STAT_NAME:
		queue_size_stat_ = LogsAndMetrics.add_server_stat(stat_name, 1)

func push(item):
	items_.push_back(QueueItem.new(item, true))
	last_valid_item_ = items_.back()
	while items_.size() > max_size_:
		items_.pop_front()

func pop() -> QueueItem:
	queue_size_stat_.add_sample(items_.size())
	if items_.is_empty():
		for i in range(target_size_):
			items_.push_back(QueueItem.DUMMY_ITEM)
	var front_item: QueueItem = items_.pop_front()
	return last_valid_item_ if _should_return_last_valid(front_item) else front_item

func _should_return_last_valid(front_item: QueueItem) -> bool:
	return !front_item.is_valid() and is_return_last_valid_ and last_valid_item_ != null

