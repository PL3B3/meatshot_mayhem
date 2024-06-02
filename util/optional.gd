extends Object
class_name Optional

const PRESENT := true
const ABSENT := false

var is_present_: bool
var value_: Variant

func _init(is_present, value):
	is_present_ = is_present
	value_ = value

static func of(value: Variant) -> Optional:
	return Optional.new(PRESENT, value)

static func empty() -> Optional:
	return Optional.new(ABSENT, null)

func is_present() -> bool:
	return is_present_

func value() -> Variant:
	return value_

func get_else_default(default: Variant) -> Variant:
	if is_present_:
		return value_
	else:
		return default

func execute_if_present(callable: Callable):
	map_if_present_else(callable, null)

func map_if_present_else(mapping_function: Callable, default: Variant) -> Variant:
	if is_present_:
		return mapping_function.call(value_)
	else:
		return default
