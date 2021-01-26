extends Node

func find_unique_name(parent: Node, prefix: String = '') -> String:
	var name: String
	while true:
		name = random_name(prefix)
		if not parent.has_node(name):
			break
	return name

func random_name(prefix: String) -> String:
	return prefix + str(randi())
