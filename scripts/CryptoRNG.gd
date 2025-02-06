# CryptoRNG.gd
extends Node

class_name CryptoRNG

var crypto: Crypto

func _init():
	crypto = Crypto.new()

func get_random_int(max_value: int) -> int:
	if max_value < 0:
		push_error("max_value must be non-negative")
		return 0
	if max_value == 0:
		return 0
	
	var bytes = crypto.generate_random_bytes(4)
	var number = bytes.decode_u32(0)
	return number % (max_value + 1)

func get_random_float() -> float:
	var bytes = crypto.generate_random_bytes(4)
	var number = bytes.decode_float(0)
	return fposmod(number, 1.0)

func shuffle_array(array: Array) -> Array:
	var n = array.size()
	for i in range(n - 1, 0, -1):
		var j = get_random_int(i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
	return array
