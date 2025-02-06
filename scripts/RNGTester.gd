# RNGTester.gd
extends Node

var CryptoRNG = preload("res://scripts/CryptoRNG.gd")

func _ready():
	var rng = CryptoRNG.new()
	
	print("Testing random integers:")
	var int_results = {}
	for i in range(1000):
		var num = rng.get_random_int(9)  # 0-9
		if num in int_results:
			int_results[num] += 1
		else:
			int_results[num] = 1
	print(int_results)
	
	print("\nTesting random floats:")
	var float_results = {"0-0.2": 0, "0.2-0.4": 0, "0.4-0.6": 0, "0.6-0.8": 0, "0.8-1.0": 0}
	for i in range(1000):
		var num = rng.get_random_float()
		if num < 0.2: float_results["0-0.2"] += 1
		elif num < 0.4: float_results["0.2-0.4"] += 1
		elif num < 0.6: float_results["0.4-0.6"] += 1
		elif num < 0.8: float_results["0.6-0.8"] += 1
		else: float_results["0.8-1.0"] += 1
	print(float_results)
	
	print("\nTesting array shuffling:")
	var array = [1, 2, 3, 4, 5]
	for i in range(5):
		print(rng.shuffle_array(array.duplicate()))
