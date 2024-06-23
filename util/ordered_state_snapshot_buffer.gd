extends Object
class_name OrderedStateSnapshotBuffer

const VALID := true
const IS_LOGGING_ENABLED := false
const TARGET_SIZE: int = 3
const MAX_SIZE: int = 6
const NO_REMOTE_CHARACTER_STATES := {}

var items_: Array[QueueItem] = []

var queue_size_at_pop_stat_: Statistics
var queue_size_at_push_stat_: Statistics
var queue_pop_misses_: Statistics
var queue_name_: String
var latest_popped_tick_: int = -1
var is_buffering_: bool = true
var last_valid_remote_character_states_ := NO_REMOTE_CHARACTER_STATES

func _init(queue_name: String) -> void:
	queue_size_at_pop_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-pop" % queue_name, 60)
	queue_size_at_push_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-push" % queue_name, 60)
	queue_pop_misses_ = LogsAndMetrics.add_counter("%s-pop-misses" % queue_name, 60)
	queue_name_ = queue_name

func push(remote_character_states: Dictionary, tick: int) -> void:
	queue_size_at_push_stat_.add_sample(items_.size())
	var value_wrapped_as_queue_item := QueueItem.new(remote_character_states, VALID, tick)
	__shrink_queue_if_over_max_size()
	__insert_item_in_order(value_wrapped_as_queue_item)

func pop() -> Dictionary:
	queue_size_at_pop_stat_.add_sample(items_.size())
	__enable_buffering_if_empty()
	if __check_if_still_buffering():
		queue_pop_misses_.increment_counter()
		return last_valid_remote_character_states_
	else:
		latest_popped_tick_ = items_[0].tick()
		var next_queued_snapshot: QueueItem = items_.pop_front()
		last_valid_remote_character_states_ = next_queued_snapshot.value()
		return next_queued_snapshot.value()

func clear_items() -> void:
	last_valid_remote_character_states_ = NO_REMOTE_CHARACTER_STATES
	items_.clear()

func __enable_buffering_if_empty() -> void:
	if items_.is_empty():
		__log("Tried to pop from empty queue. Returning last valid snapshot until %d new snapshots are buffered", [
			queue_name_, TARGET_SIZE])
		is_buffering_ = true

func __check_if_still_buffering() -> bool:
	if is_buffering_ and items_.size() < TARGET_SIZE:
		__log("Currently at %d items, buffering until %d items", [items_.size(), TARGET_SIZE])
	else:
		is_buffering_ = false
	return is_buffering_

func __shrink_queue_if_over_max_size() -> void:
	if items_.size() >= MAX_SIZE:
		__log(
			"Queue has more than %d items, discarding oldest items until size reaches %d", 
			[queue_name_, MAX_SIZE, TARGET_SIZE])
		while items_.size() > TARGET_SIZE:
			items_.pop_front()

func __insert_item_in_order(item: QueueItem) -> void:
	if item.tick() <= latest_popped_tick_:
		return
	for i in items_.size():
		if items_[i].tick() > item.tick():
			items_.insert(i, item)
			return
		elif items_[i].tick() == item.tick():
			items_[i] = item
			return
	__append_item_with_highest_tick_to_end_of_buffer(item)

func __append_item_with_highest_tick_to_end_of_buffer(item: QueueItem) -> void:
	items_.push_back(item)

func __log(format_string: String, args: Array[Variant] = []) -> void:
	if IS_LOGGING_ENABLED:
		var log_message: String = format_string % args
		print("%s :: %s" % [queue_name_, log_message])
