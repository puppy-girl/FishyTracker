extends Node

var fish_log: Array = [] setget _set_nullifier

var _last_inventory_size: int = 0 setget _set_nullifier
var _fish_log_refs: Array = [] setget _set_nullifier


func _ready() -> void:
	get_tree().connect("node_added", self, "_on_node_added")
	PlayerData.connect("_inventory_refresh", self, "_on_inventory_update")
	UserSave.connect("_slot_saved", self, "_save_fish_logs")
	
	var save_slot = UserSave.current_loaded_slot
	if save_slot != -1: # loaded slot is -1 when there's no save file
		_load_fish_logs(save_slot)


func _on_node_added(node: Node) -> void:
	if (
			node.name == "save_select"
			or node.name.begins_with("@save_select@")
			and node.get_parent().name != "main_menu"
	):
		node.connect("_pressed", self, "_switch_save_slot", [], CONNECT_DEFERRED)


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
		var is_fish: bool = entry.id.begins_with("fish_")
		
		if not is_fish or entry.ref in _fish_log_refs:
			continue
		
		fish_log.append(entry)
		_fish_log_refs.append(entry.ref)


func _save_fish_logs() -> void:
	var save_slot: int = UserSave.current_loaded_slot
	var save: Dictionary = {
		"fish_log": fish_log
	}
	
	var dir := Directory.new()
	if !dir.dir_exists("user://FishyTracker"):
		dir.make_dir("user://FishyTracker")
	
	var file := File.new()
	file.open("user://FishyTracker/fish_log_slot_%s.dat" % save_slot, File.WRITE)
	file.store_string(JSON.print(save))
	file.close()


func _load_fish_logs(save_slot: int) -> void:
	var file := File.new()
	file.open("user://FishyTracker/fish_log_slot_%s.dat" % save_slot, File.READ)
	var content := file.get_as_text()
	file.close()
	
	var stored_json := JSON.parse(content)
	if stored_json.error != OK:
		push_warning("Could not parse JSON from fish logs file")
		return
	fish_log = stored_json.result.fish_log
	
	_fish_log_refs = []
	for entry in fish_log:
		_fish_log_refs.append(entry.ref)
	
	_last_inventory_size = PlayerData.inventory.size()


func _switch_save_slot() -> void:
	var save_slot: int = UserSave.current_loaded_slot
	
	_load_fish_logs(save_slot)


func _set_nullifier(_v) -> void:
	return
