extends RefCounted

const VERSION := 1
const FLOAT_DIGITS := 9

func hash_state(state: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical_string(state).to_utf8_buffer())
	return context.finish().hex_encode()

func canonical_string(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "b:1" if value else "b:0"
		TYPE_INT:
			return "i:%d" % int(value)
		TYPE_FLOAT:
			return _canonical_float(float(value))
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return "s:%s" % JSON.stringify(String(value))
		TYPE_VECTOR2:
			return "v2:(%s,%s)" % [_canonical_float(value.x), _canonical_float(value.y)]
		TYPE_VECTOR2I:
			return "v2i:(%d,%d)" % [value.x, value.y]
		TYPE_RECT2:
			return "r2:(%s,%s,%s,%s)" % [_canonical_float(value.position.x), _canonical_float(value.position.y), _canonical_float(value.size.x), _canonical_float(value.size.y)]
		TYPE_COLOR:
			return "c:(%s,%s,%s,%s)" % [_canonical_float(value.r), _canonical_float(value.g), _canonical_float(value.b), _canonical_float(value.a)]
		TYPE_ARRAY:
			var entries: Array[String] = []
			for entry in value:
				entries.append(canonical_string(entry))
			return "a:[%s]" % ",".join(entries)
		TYPE_DICTIONARY:
			return _canonical_dictionary(value)
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return canonical_string(Array(value))
		_:
			return "variant:%d:%s" % [typeof(value), JSON.stringify(str(value))]

func _canonical_dictionary(value: Dictionary) -> String:
	var ordered: Array[Dictionary] = []
	for key in value.keys():
		ordered.append({"key": key, "encoded": canonical_string(key)})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.encoded) < String(b.encoded))
	var entries: Array[String] = []
	for item in ordered:
		entries.append("%s=%s" % [String(item.encoded), canonical_string(value[item.key])])
	return "d:{%s}" % ",".join(entries)

func _canonical_float(value: float) -> String:
	if is_nan(value):
		return "f:nan"
	if is_inf(value):
		return "f:+inf" if value > 0.0 else "f:-inf"
	if is_zero_approx(value):
		value = 0.0
	return "f:%s" % String.num(value, FLOAT_DIGITS)
