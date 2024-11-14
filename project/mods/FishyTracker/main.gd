extends Node

onready var _last_inventory_size: int = PlayerData.inventory.size()

var fish_log: Array = [] setget _set_nullifier


func _init() -> void:
	pass


func _ready() -> void:
	PlayerData.connect("_inventory_refresh", self, "_on_inventory_update")


func _on_inventory_update() -> void:
	var inventory_size: int = PlayerData.inventory.size()
	var fish_log_size: int = fish_log.size()
	
	var new_entries: int = inventory_size - _last_inventory_size
	
	if new_entries <= 0:
		_last_inventory_size = inventory_size
		return
	
	_last_inventory_size = inventory_size
	
	for i in new_entries:
		var entry_index: int = inventory_size - new_entries + i
		var entry: Dictionary = PlayerData.inventory[entry_index]
		var is_fish: bool = entry.id.begins_with("fish")
	
		if (
				fish_log_size > 0
				and fish_log[fish_log_size - 1].ref == entry.ref
		):
			continue
	
		if is_fish:
			fish_log.append(entry)


func _set_nullifier(_v) -> void:
	return
