extends Object

static func get_interface(interface_name: String) -> Object:
	if Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript")
	return null

static func eval(code: String) -> Variant:
	if Engine.has_singleton("JavaScript"):
		return Engine.get_singleton("JavaScript").eval(code)
	return null
