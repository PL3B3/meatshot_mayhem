extends Node
class_name DataClassGenerator

const TAB = "\t"
const NEWLINE = "\n"
const CLASS_NAME_KEY = "name"
const PROPERTIES_KEY = "properties"
const PROPERTY_NAME_KEY = "name"
const PROPERTY_TYPE_KEY = "type"
const PRIVATE_PROPERTY_SUFFIX = "_"
const CLASS_HEADER_TEMPLATE = """extends Object
class_name %s\n"""
const ENUM_TEMPLATE = """enum %s {
%s
}\n"""
const CONSTRUCTOR_TEMPLATE = """func _init(%s):
%s\n"""
const GETTER_TEMPLATE = """func %s() -> %s:
	return %s%s\n"""
const TO_DICT_TEMPLATE = """func to_dict() -> Dictionary:
	return {
%s
	}\n"""
const FROM_DICT_TEMPLATE = """static func from_dict(dict: Dictionary) -> %s:
	return %s.new(
%s
	)\n"""
const TO_STRING_TEMPLATE = """func _to_string() -> String:
	return \"%s<%s>\" %% [
%s    
	]\n"""


"""
WARNING: CANNOT HANDLE NESTED COMPLEX TYPES. 
---------------------------------------------------------------------
USE THIS AS A STARTING POINT, NOT A FULL GENERATOR!!!
---------------------------------------------------------------------

Format is like this, but put quotes around everything. not doing b/c it's confusing w/ escape characters
{
	name: PascalCaseClassName,
	properties: [
		{
			name: snake_case_property_name,
			type: godot type, like Vector3
		}
	] 
}
"""

func _ready():
	var json_spec = """
	{
		"name": "ClientRemoteCharacterState",
		"properties": [
			{
				"name": "entity_id",
				"type": "int"
			},
			{
				"name": "transform",
				"type": "CharacterTransformState"
			}
		]
	}
	"""
	var json_spec_2 = """
	{
		"name": "ClientOwnCharacterState",
		"properties": [
			{
				"name": "entity_id",
				"type": "int"
			},
			{
				"name": "physics_state",
				"type": "CharacterPhysicsState"
			}
		]
	}
	"""
	var json_spec_3 = """
	{
		"name": "ClientStateSnapshot",
		"properties": [
			{
				"name": "own_character_state",
				"type": "ClientOwnCharacterState"
			},
			{
				"name": "remote_character_states",
				"type": "Array[ClientRemoteCharacterState]"
			}
		]
	}
	"""
	var json_spec_4 = """
	{
		"name": "ServerToClientStateSnapshotMessage",
		"properties": [
			{
				"name": "client_tick",
				"type": "int"
			},
			{
				"name": "own_character_state",
				"type": "ClientStateSnapshot"
			}
		]
	}
	"""
	print(DataClassGenerator.generate_data_class(json_spec_4))

static func generate_data_class(json_spec: String):
	var json_parser = JSON.new()
	var json_parse_error = json_parser.parse(json_spec)
	if json_parse_error == OK:
		var data_class_spec: __DataClassSpec = __parse_data_class_spec(json_parser.data)
		return NEWLINE.join([
			__generate_class_header(data_class_spec),
			__generate_property_enum(data_class_spec),
			__generate_properties(data_class_spec),
			__generate_constructor(data_class_spec),
			__generate_getters(data_class_spec),
			__generate_to_dict(data_class_spec),
			__generate_from_dict(data_class_spec),
			__generate_to_string(data_class_spec),
		])
	else:
		print("JSON Parse Error: ", json_parser.get_error_message(), " in ", json_spec, " at line ", json_parser.get_error_line())
		return ""

static func __parse_data_class_spec(spec_dictionary: Dictionary) -> __DataClassSpec:
	var data_class_name: String = spec_dictionary[CLASS_NAME_KEY]
	assert(__is_pascal_case(data_class_name), "Data class name %s must be PascalCase" % data_class_name)
	var raw_properties: Array = spec_dictionary[PROPERTIES_KEY]
	var parsed_properties: Array[__PropertySpec] = []
	for raw_property in raw_properties:
		var property_name = raw_property[PROPERTY_NAME_KEY]        
		var property_type = raw_property[PROPERTY_TYPE_KEY]
		assert(__is_snake_case(property_name), "Property name %s must be snake_case" % property_name)
		parsed_properties.push_back(__PropertySpec.new(property_name, property_type))
	return __DataClassSpec.new(data_class_name, parsed_properties)

static func __is_pascal_case(string: String):
	return string == string.to_pascal_case()

static func __is_snake_case(string: String):
	return string == string.to_snake_case()

static func __generate_class_header(class_spec: __DataClassSpec) -> String:
	return CLASS_HEADER_TEMPLATE % class_spec.name()

static func __generate_property_enum(class_spec: __DataClassSpec) -> String:
	var property_enum_values: Array[String] = []
	for property in class_spec.properties():
		property_enum_values.push_back("%s%s" % [TAB, __convert_property_name_to_enum_value(property.name())])
	var enum_values_string = ("," + NEWLINE).join(property_enum_values)
	return ENUM_TEMPLATE % [__convert_class_name_to_enum_name(class_spec.name()), enum_values_string]

static func __generate_properties(class_spec: __DataClassSpec) -> String:
	var property_lines: Array[String] = []
	for property in class_spec.properties():
		property_lines.push_back("var %s%s: %s" % [property.name(), PRIVATE_PROPERTY_SUFFIX, property.type()])
	return NEWLINE.join(property_lines) + NEWLINE

static func __generate_constructor(class_spec: __DataClassSpec) -> String:
	var parameters: Array[String] = []
	var setter_lines: Array[String] = []
	for property in class_spec.properties():
		parameters.push_back("%s: %s" % [property.name(), property.type()])
		setter_lines.push_back("%s%s%s = %s" % [TAB, property.name(), PRIVATE_PROPERTY_SUFFIX, property.name()])
	return CONSTRUCTOR_TEMPLATE % [", ".join(parameters), NEWLINE.join(setter_lines)]

static func __generate_getters(class_spec: __DataClassSpec) -> String:
	var getter_definitions: Array[String] = []
	for property in class_spec.properties():
		getter_definitions.push_back(GETTER_TEMPLATE % [
			property.name(), property.type(), property.name(), PRIVATE_PROPERTY_SUFFIX])
	return NEWLINE.join(getter_definitions)

static func __generate_to_dict(class_spec: __DataClassSpec) -> String:
	var serialized_property_entries: Array[String] = []
	var property_enum_name = __convert_class_name_to_enum_name(class_spec.name())
	for property in class_spec.properties():
		serialized_property_entries.push_back("%s.%s: %s%s" % [
			property_enum_name,
			__convert_property_name_to_enum_value(property.name()),
			property.name(), 
			PRIVATE_PROPERTY_SUFFIX])
	var property_entries_string = ("," + NEWLINE).join(serialized_property_entries).indent(TAB + TAB)
	return TO_DICT_TEMPLATE % property_entries_string

static func __generate_from_dict(class_spec: __DataClassSpec) -> String:
	var extract_property_entries: Array[String] = []
	var property_enum_name = __convert_class_name_to_enum_name(class_spec.name())
	for property in class_spec.properties():
		extract_property_entries.push_back("dict[%s.%s]" % [
			property_enum_name, __convert_property_name_to_enum_value(property.name())])
	var property_entries_string = ("," + NEWLINE).join(extract_property_entries).indent(TAB + TAB)
	return FROM_DICT_TEMPLATE % [class_spec.name(), class_spec.name(), property_entries_string]

static func __generate_to_string(class_spec: __DataClassSpec) -> String:
	var property_format_string_placeholders: Array[String] = []
	var property_format_string_parameters: Array[String] = []
	for property in class_spec.properties():
		property_format_string_placeholders.push_back("%s=%%s" % __convert_property_name_to_enum_value(property.name()))
		property_format_string_parameters.push_back("%s%s" % [property.name(), PRIVATE_PROPERTY_SUFFIX])
	var property_placeholders_string = ", ".join(property_format_string_placeholders)
	var property_parameters_string = ("," + NEWLINE).join(property_format_string_parameters).indent(TAB + TAB)
	return TO_STRING_TEMPLATE % [class_spec.name(), property_placeholders_string, property_parameters_string]

static func __convert_class_name_to_enum_name(data_class_name: String) -> String:
	return data_class_name.to_snake_case().to_upper()

static func __convert_property_name_to_enum_value(property_name: String) -> String:
	return property_name.to_upper()

class __DataClassSpec:
	enum DATA_CLASS_SPEC {
		NAME,
		PROPERTIES
	}
	
	var name_: String
	var properties_: Array[__PropertySpec]
	
	func _init(name: String, properties: Array[__PropertySpec]):
		name_ = name
		properties_ = properties
	
	func name() -> String:
		return name_
	
	func properties() -> Array[__PropertySpec]:
		return properties_
	
	func to_dict() -> Dictionary:
		return {
			DATA_CLASS_SPEC.NAME: name_,
			DATA_CLASS_SPEC.PROPERTIES: properties_
		}
	
	static func from_dict(dict: Dictionary) -> __DataClassSpec:
		return __DataClassSpec.new(
			dict[DATA_CLASS_SPEC.NAME],
			dict[DATA_CLASS_SPEC.PROPERTIES]
		)
	
	func _to_string() -> String:
		return "__DataClassSpec<NAME=%s, PROPERTIES=%s>" % [
			name_,
			properties_    
		]
	
class __PropertySpec:
	enum PROPERTY_SPEC {
		NAME,
		TYPE
	}
	
	var name_: String
	var type_: String
	
	func _init(name: String, type: String):
		name_ = name
		type_ = type
	
	func name() -> String:
		return name_
	
	func type() -> String:
		return type_
	
	func to_dict() -> Dictionary:
		return {
			PROPERTY_SPEC.NAME: name_,
			PROPERTY_SPEC.TYPE: type_
		}
	
	static func from_dict(dict: Dictionary) -> __PropertySpec:
		return __PropertySpec.new(
			dict[PROPERTY_SPEC.NAME],
			dict[PROPERTY_SPEC.TYPE]
		)
	
	func _to_string() -> String:
		return "__PropertySpec<NAME=%s, TYPE=%s>" % [
			name_,
			type_    
		]
