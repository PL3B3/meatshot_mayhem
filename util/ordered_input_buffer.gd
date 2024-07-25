extends RefCounted
class_name OrderedInputBuffer

const VALID := true
const IS_LOGGING_ENABLED := false
const DO_NOT_RETRIGGER_JUMP_IN_EXTRAPOLATED_INPUT := false
const STANDING_STILL_INPUT_DOES_NOT_SLOW_WALK := false
const EXTRAPOLATED_INPUTS_CANNOT_TRIGGER_ABILITY := false
const MAXIMUM_TIMES_TO_RETURN_LAST_VALID_INPUT := 5
const NO_MOVE_DIRECTION := Vector2.ZERO
const DISPLAYED_TICK_IRRELEVANT_FOR_EXTRAPOLATED_INPUT := -1
const NO_CLIENT_RECONCILIATION_FOR_EXTRAPOLATED_INPUT := Network.NO_TICK
static var DEFAULT_CLIENT_INPUT := ClientInput.new(
	InputState.DEFAULT, 
	EXTRAPOLATED_INPUTS_CANNOT_TRIGGER_ABILITY, 
	DISPLAYED_TICK_IRRELEVANT_FOR_EXTRAPOLATED_INPUT)

var target_size_: int
var max_size_: int
var input_buffer_: Array[QueuedInput] = []

var queue_size_at_pop_stat_: Statistics
var queue_size_at_push_stat_: Statistics
var queue_pop_misses_: Statistics
var queue_name_: String
var latest_popped_tick_: int = -1
var is_buffering_: bool = true
var ticks_in_a_row_returned_last_valid_input_ := 0
var last_valid_input_: ClientInput = DEFAULT_CLIENT_INPUT

func _init(
	queue_name: String,
	target_size: int = 3, 
	max_size: int = 6
) -> void:
	assert(target_size > 0)
	queue_name_ = queue_name
	queue_size_at_pop_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-pop" % queue_name, 60)
	queue_size_at_push_stat_ = LogsAndMetrics.add_universal_stat("%s-size-at-push" % queue_name, 60)
	queue_pop_misses_ = LogsAndMetrics.add_counter("%s-pop-misses" % queue_name, 60)
	target_size_ = target_size
	max_size_ = max_size

func push(client_input: ClientInput) -> void:
	queue_size_at_push_stat_.add_sample(input_buffer_.size())
	var value_wrapped_as_queue_item := QueuedInput.new(client_input, VALID)
	__shrink_queue_if_over_max_size()
	__insert_item_in_order(value_wrapped_as_queue_item)

func pop() -> ClientInput:
	queue_size_at_pop_stat_.add_sample(input_buffer_.size())
	__enable_buffering_if_empty()
	if __check_if_still_buffering():
		queue_pop_misses_.increment_counter()
		return __extrapolate_input_to_return_when_buffer_empty()
	else:
		ticks_in_a_row_returned_last_valid_input_ = 0
		latest_popped_tick_ = input_buffer_[0].tick()
		var next_input: QueuedInput = input_buffer_.pop_front()
		last_valid_input_ = next_input.value
		return next_input.value

func __enable_buffering_if_empty() -> bool:
	if input_buffer_.is_empty():
		__log("Tried to pop from empty queue. Returning dummy items until %d valid items are buffered", [
			queue_name_, target_size_])
		is_buffering_ = true
		return true
	else:
		return false

func __check_if_still_buffering() -> bool:
	if is_buffering_ and input_buffer_.size() < target_size_:
		__log("Currently at %d items, buffering until %d items", [input_buffer_.size(), target_size_])
	else:
		is_buffering_ = false
	return is_buffering_

func __shrink_queue_if_over_max_size() -> void:
	if input_buffer_.size() >= max_size_:
		__log(
			"Queue has more than %d items, discarding oldest items until size reaches %d", 
			[queue_name_, max_size_, target_size_])
		while input_buffer_.size() > target_size_:
			input_buffer_.pop_front()

func __insert_item_in_order(queued_input: QueuedInput) -> void:
	if queued_input.tick() <= latest_popped_tick_:
		return
	for i in input_buffer_.size():
		if input_buffer_[i].tick() > queued_input.tick():
			input_buffer_.insert(i, queued_input)
			return
		elif input_buffer_[i].tick() == queued_input.tick():
			input_buffer_[i] = queued_input
			return
	__append_item_with_highest_tick_to_end_of_buffer(queued_input)

func __append_item_with_highest_tick_to_end_of_buffer(queued_input: QueuedInput) -> void:
	input_buffer_.push_back(queued_input)

func __extrapolate_input_to_return_when_buffer_empty() -> ClientInput:
	var input_to_return: ClientInput
	if ticks_in_a_row_returned_last_valid_input_ < MAXIMUM_TIMES_TO_RETURN_LAST_VALID_INPUT:
		ticks_in_a_row_returned_last_valid_input_ += 1
		input_to_return = __copy_last_valid_client_input_without_triggers(last_valid_input_)
		__log("Using last valid input as placeholder: %s", [input_to_return])
	else:
		input_to_return = __create_default_input_state_with_last_known_view_angle(last_valid_input_)
		__log("Using default input as placeholder: %s", [input_to_return])
	return input_to_return

static func __create_default_input_state_with_last_known_view_angle(last_valid_input: ClientInput) -> ClientInput:
	var input_state_standing_still_with_last_known_view_angle := InputState.new(
		last_valid_input.input_state().yaw(),
		last_valid_input.input_state().pitch(),
		DO_NOT_RETRIGGER_JUMP_IN_EXTRAPOLATED_INPUT,
		STANDING_STILL_INPUT_DOES_NOT_SLOW_WALK,
		NO_MOVE_DIRECTION,
		NO_CLIENT_RECONCILIATION_FOR_EXTRAPOLATED_INPUT)
	return ClientInput.new(
		input_state_standing_still_with_last_known_view_angle, 
		EXTRAPOLATED_INPUTS_CANNOT_TRIGGER_ABILITY,
		DISPLAYED_TICK_IRRELEVANT_FOR_EXTRAPOLATED_INPUT)

static func __copy_last_valid_client_input_without_triggers(client_input: ClientInput) -> ClientInput:
	var input_state_to_copy := client_input.input_state()
	var copied_input_without_triggers := InputState.new(
		input_state_to_copy.yaw(),
		input_state_to_copy.pitch(),
		DO_NOT_RETRIGGER_JUMP_IN_EXTRAPOLATED_INPUT,
		input_state_to_copy.is_slow_walking(),
		input_state_to_copy.direction(),
		NO_CLIENT_RECONCILIATION_FOR_EXTRAPOLATED_INPUT)
	return ClientInput.new(
		copied_input_without_triggers, 
		EXTRAPOLATED_INPUTS_CANNOT_TRIGGER_ABILITY,
		DISPLAYED_TICK_IRRELEVANT_FOR_EXTRAPOLATED_INPUT)

func __log(format_string: String, args: Array[Variant] = []) -> void:
	if IS_LOGGING_ENABLED:
		var log_message: String = format_string % args
		print("%s :: %s" % [queue_name_, log_message])

class QueuedInput:
	var value: ClientInput
	var is_valid: bool

	func _init(value: ClientInput, is_valid: bool) -> void:
		self.value = value
		self.is_valid = is_valid
	
	func tick() -> int:
		return value.input_state().client_tick()
