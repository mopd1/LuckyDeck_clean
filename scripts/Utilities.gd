extends Node

static func format_number(number):
	var str_number = str(number)
	var result = ""
	var count = 0
	
	for i in range(str_number.length() - 1, -1, -1):
		result = str_number[i] + result
		count += 1
		if count == 3 and i > 0 and str_number[i-1] != '-':
			result = "," + result
			count = 0
	
	return result
