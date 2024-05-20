extends Object
class_name Result

const NO_ERROR = "NO ERROR"

var error_: String
var value_: Variant

func _init(error: String, value: Variant):
    error_ = error
    value_ = value

static func without_error(value: Variant) -> Result:
    return Result.new(NO_ERROR, value)

static func of_error(error: String) -> Result:
    return Result.new(error, null)

func error() -> String:
    return error_

func value() -> Variant:
    return value_

func is_valid() -> bool:
    return error_ == NO_ERROR

func execute_if_valid(callable: Callable):
    map_if_valid_else_default(callable, null)

func map_if_valid_else_default(callable: Callable, default: Variant) -> Variant:
    if is_valid():
        return callable.call(value_)
    else:
        return default