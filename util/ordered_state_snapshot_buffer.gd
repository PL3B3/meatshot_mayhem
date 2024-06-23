extends Object
class_name OrderedStateSnapshotBuffer

const FROM_SERVER := true
const INTERPOLATED := false
const IS_LOGGING_ENABLED := false
const TARGET_SIZE: int = 4
const MAX_SIZE: int = 8
const NO_REMOTE_CHARACTER_STATES := {}


var queue_size_at_pop_stat_: Statistics
var queue_size_at_push_stat_: Statistics
var queue_name_: String

var queue_pop_misses_: Statistics
var latest_popped_tick_: int = Network.NO_TICK
var is_buffering_: bool = true
var last_valid_remote_character_states_ := NO_REMOTE_CHARACTER_STATES
var items_: Array[QueueItem] = []

func _init(queue_name: String) -> void:
	queue_size_at_pop_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-pop" % queue_name, 60)
	queue_size_at_push_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-push" % queue_name, 60)
	queue_pop_misses_ = LogsAndMetrics.add_counter("%s-pop-misses" % queue_name, 10)
	queue_name_ = queue_name

func push(remote_character_states: Dictionary, tick: int) -> void:
	queue_size_at_push_stat_.add_sample(items_.size())
	var value_wrapped_as_queue_item := QueueItem.new(remote_character_states, FROM_SERVER, tick)
	__shrink_queue_if_over_max_size()
	__insert_item_in_order(value_wrapped_as_queue_item)
	__fill_in_buffer_gap_with_interpolated_states(value_wrapped_as_queue_item)

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
			__overwrite_existing_state_if_new_state_is_authoritative(i, item)
			return
	__append_item_with_highest_tick_to_end_of_buffer(item)

func __overwrite_existing_state_if_new_state_is_authoritative(
	index_of_item_with_same_tick: int, 
	newly_received_item: QueueItem
) -> void:
	if newly_received_item.is_valid() == FROM_SERVER:
		items_[index_of_item_with_same_tick] = newly_received_item

func __append_item_with_highest_tick_to_end_of_buffer(item: QueueItem) -> void:
	items_.push_back(item)

func __fill_in_buffer_gap_with_interpolated_states(item_to_insert: QueueItem) -> void:
	var latest_authoritative_snapshot_before_item: QueueItem = null
	for buffered_snapshot_item: QueueItem in items_:
		if buffered_snapshot_item.tick() < item_to_insert.tick() and buffered_snapshot_item.is_valid() == FROM_SERVER:
			latest_authoritative_snapshot_before_item = buffered_snapshot_item
	if latest_authoritative_snapshot_before_item != null:
		__log(
			"Interpolating snapshot states between tick %d and %d", 
			[latest_authoritative_snapshot_before_item.tick(), item_to_insert.tick()])
		var interpolated_snapshots_to_add := __compute_interpolated_states(
			latest_authoritative_snapshot_before_item, item_to_insert)
		for interpolated_snapshot: QueueItem in interpolated_snapshots_to_add:
			__insert_item_in_order(interpolated_snapshot)
	else:
		__log("No authoritative states in buffer with tick lower than %d", [item_to_insert.tick()])

func __compute_interpolated_states(source_item: QueueItem, target_item: QueueItem) -> Array[QueueItem]:
	var interpolated_snapshots: Array[QueueItem] = []
	var ticks_between_source_and_target_snapshot: int = target_item.tick() - source_item.tick() 
	var range_between_source_and_target_tick_excluding_ends := range(
		1, ticks_between_source_and_target_snapshot)
	for interpolation_offset_in_ticks: int in range_between_source_and_target_tick_excluding_ends:
		var interpolation_fraction: float = (
			float(interpolation_offset_in_ticks) / ticks_between_source_and_target_snapshot)
		var interpolated_state := StateInterpolationUtils.interpolate_remote_state_snapshots(
			source_item.value(), 
			target_item.value(), 
			interpolation_fraction)
		var tick_of_interpolated_state: int = source_item.tick() + interpolation_offset_in_ticks
		var interpolated_item := QueueItem.new(interpolated_state, INTERPOLATED, tick_of_interpolated_state)
		interpolated_snapshots.push_back(interpolated_item)
	return interpolated_snapshots

func __log(format_string: String, args: Array[Variant] = []) -> void:
	if IS_LOGGING_ENABLED:
		var log_message: String = format_string % args
		print("%s :: %s" % [queue_name_, log_message])
