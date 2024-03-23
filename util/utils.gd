class_name Utils

static func get_only_element_of_list(list: Array):
	assert(list.size() == 1, "Cannot get only element of list with size != 1")
	return list[0]

static func get_or_default(dictionary, key, default_value):
	if !dictionary.has(key):
		return default_value
	return dictionary[key]

static func default_if_absent(dict: Dictionary, key, default_value):
	return compute_if_absent(dict, key, func(key): return default_value)

static func compute_if_absent(dict: Dictionary, key, compute_func):
	if not key in dict:
		dict[key] = compute_func.call(key)
	return dict[key]
