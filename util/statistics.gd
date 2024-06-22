extends Node

class_name Statistics

signal new_statistic_calculated(stat_blurb: String)

const USE_DIFF = true
const RAW_VALUE = false
const DEFAULT_INTERVAL = 5.0
const DUMMY_SAMPLE_FOR_COUNTER = 1

var statistic_name_: String
var use_diff_: bool
var network_mode_: int
var samples_: Array = []
var last_value_: Array = []
var interval_sec_: float
var is_counter_: bool

func _init(
	statistic_name: String, 
	use_diff: bool, 
	network_mode: int, 
	interval_sec: float=DEFAULT_INTERVAL, 
	is_counter=false
):
	statistic_name_ = statistic_name
	use_diff_ = use_diff
	network_mode_ = network_mode
	interval_sec_ = interval_sec
	is_counter_ = is_counter

func _ready():
	var timer = Timer.new()
	timer.set_wait_time(interval_sec_)
	timer.set_one_shot(false)
	timer.timeout.connect(print_and_clear_stats)
	add_child(timer)
	timer.start()

func increment_counter() -> void:
	if !should_display(network_mode_):
		return
	samples_.push_back(DUMMY_SAMPLE_FOR_COUNTER)

func add_sample(raw_sample):
	if !should_display(network_mode_):
		return
	if use_diff_:
		if last_value_.is_empty():
			last_value_.push_back(raw_sample)
			return
		else:
			samples_.push_back(float(raw_sample - last_value_[0]))
			last_value_[0] = raw_sample
	else:
		samples_.push_back(float(raw_sample))

func print_and_clear_stats() -> void:
	if !should_display(network_mode_):
		return
	if samples_.is_empty():
		print_with_network_role("%s: cannot calculate statistics: no samples" % statistic_name_)
		return
	var stat_blurb: String
	if is_counter_:
		stat_blurb = __create_counter_blurb()
	else:
		stat_blurb = __create_stat_blurb()
	new_statistic_calculated.emit(stat_blurb)
	print_with_network_role(stat_blurb)
	samples_.clear()

func __create_counter_blurb() -> String:
	return "%s: count: %d" % [statistic_name_, samples_.size()]

func __create_stat_blurb() -> String:
	samples_.sort()
	var max = samples_[-1]
	var min = samples_[0]
	var median = samples_[int(samples_.size() / 2)]
	var mean = samples_.reduce(func(accum, sample): return accum + (sample / float(samples_.size())), 0.0)
	var total_variance = samples_.reduce(func(curr_total, sample): return curr_total + pow(sample - mean, 2), 0.0)
	var std_dev = sqrt(total_variance / max(1.0, samples_.size() - 1.0))
	return "%s: median: %.3f, mean: %.3f, std_dev: %.3f, min: %.3f, max: %.3f" % [
		statistic_name_, median, mean, std_dev, min, max]

func network_mode():
	return network_mode_

func should_display(network_mode):
	match network_mode:
		NetworkLogMode.CLIENT_ONLY:
			return !multiplayer.is_server()
		NetworkLogMode.SERVER_ONLY:
			return multiplayer.is_server()
		NetworkLogMode.CLIENT_AND_SERVER:
			return true
		_:
			print("%s is not a valid value of NetworkLogMode. Not displaying log or stat" % network_mode)
			return false

func print_with_network_role(message: String):
	print("%s %s" % [get_network_role_descriptor(), message])

func get_network_role_descriptor():
	if multiplayer.is_server():
		return "<SV::%010d>" % multiplayer.get_unique_id()
	else:
		return "<CL::%10d>" % multiplayer.get_unique_id()
