extends Node

enum Quality { NORMAL, SHINING, GLISTENING, OPULENT, RADIANT, ALPHA }
enum Size { BUGGED, MICROSCOPIC, TINY, SMALL, NORMAL, LARGE, HUGE, MASSIVE, GIGANTIC, COLOSSAL }

const SIZE_THRESHOLD := {
	Size.BUGGED: 0.0,
	Size.MICROSCOPIC: 0.1,
	Size.TINY: 0.25,
	Size.SMALL: 0.5,
	Size.NORMAL: 1.0,
	Size.LARGE: 1.5,
	Size.HUGE: 1.75,
	Size.MASSIVE: 2.25,
	Size.GIGANTIC: 2.75,
	Size.COLOSSAL: 3.25,
}
const SIZE_PREFIX := {
	Size.BUGGED: "???",
	Size.MICROSCOPIC: "Micro",
	Size.TINY: "Tiny",
	Size.SMALL: "Small",
	Size.NORMAL: "Normal",
	Size.LARGE: "Large",
	Size.HUGE: "Huge",
	Size.MASSIVE: "Massive",
	Size.GIGANTIC: "Gigantic",
	Size.COLOSSAL: "Colossal",
}

var catch_journal: Dictionary = {} setget _set_nullifier
var fish_log: Array = [] setget _set_nullifier

var _last_inventory_size: int = 0 setget _set_nullifier
var _fish_log_refs: Array = [] setget _set_nullifier


func _ready() -> void:
	get_tree().connect("node_added", self, "_on_node_added")
	PlayerData.connect("_inventory_refresh", self, "_on_inventory_update")
	UserSave.connect("_slot_saved", self, "_save_fish_logs")


func get_size(fish_id: String, fish_size: float) -> int:
	var index := 0
	var average_size: float = Globals.item_data[fish_id]["file"].average_size
	fish_size /= average_size

	for threshold in SIZE_THRESHOLD.values():
		if not fish_size > threshold:
			break
		index += 1

	return index - 1  # loop offsets the index by 1


func _on_node_added(node: Node) -> void:
	# Load the save file when we reach the main menu
	if node.name == "main_menu":
		var save_slot := UserSave.current_loaded_slot
		if save_slot != -1:  # loaded slot is -1 when there's no save file
			_load_fish_logs(save_slot)

		# Update the tooltip styling for tables
		var tooltip_body = $"/root/Tooltip/Panel/body"
		tooltip_body.set("custom_constants/table_hseparation", 0)
		tooltip_body.set("custom_constants/table_vseparation", -7)

	# When the save select buttons are created, connect to each button to switch the loaded save
	if (
		(node.name == "save_select" or node.name.begins_with("@save_select@"))
		and node.get_parent().name != "main_menu"
	):
		node.connect("_pressed", self, "_switch_save_slot", [], CONNECT_DEFERRED)

	# Whenever a tooltip is added to the journal menu, pass the node to _update_tooltip
	if node.name == "tooltip_node" and node.get_parent().name.find("Control") != -1:
		node.connect("ready", self, "_update_tooltip", [node], CONNECT_DEFERRED)


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

		var fish_name: String = Globals.item_data[entry.id]["file"].item_name

		if not fish_name in catch_journal:
			catch_journal[fish_name] = int()
		catch_journal[fish_name] |= 1 << get_size(entry.id, entry.size) * 6 << entry.quality

		fish_log.append(entry)
		_fish_log_refs.append(entry.ref)


func _update_tooltip(tooltip: Node) -> void:
	# Skip tooltips for fish that haven't been caught yet
	if tooltip.header.find("UNKNOWN") != -1:
		return

	var fish_name: String = tooltip.header.substr(15, tooltip.header.length() - 23)
	# Skip tooltips for fish that aren't in the catch journal
	if not fish_name in catch_journal:
		return

	var cells := ["[cell][/cell]"]  # start with a blank cell

	for quality in Quality.values():
		cells.append(
			"[cell][img]res://mods/FishyTracker/assets/qualities/%s.png[/img][/cell]" % quality
		)

	for size in Size.values():
		cells.append("[cell][color=#b48141]%s [/color][/cell]" % SIZE_PREFIX[size])

		var qualities: int = catch_journal[fish_name] >> size * 6 & 0b111111
		for quality in 6:
			var caught: bool = qualities & 1 << quality
			var icon := (
				"res://mods/FishyTracker/assets/star.png"
				if caught
				else "res://mods/FishyTracker/assets/no_star.png"
			)
			cells.append("[cell][img]%s[/img][/cell]" % icon)

	tooltip.body += "\n\n[table=%s]%s[/table]" % [Quality.size() + 1, "".join(cells)]


func _save_fish_logs() -> void:
	var save_slot: int = UserSave.current_loaded_slot
	var save_data: Dictionary = {"catch_journal": catch_journal, "fish_log": fish_log}
	var file := File.new()
	var dir := Directory.new()

	if !dir.dir_exists("user://FishyTracker"):
		dir.make_dir("user://FishyTracker")

	file.open("user://FishyTracker/fish_log_slot_%s.dat" % save_slot, File.WRITE)
	file.store_string(JSON.print(save_data))
	file.close()


func _load_fish_logs(save_slot: int) -> void:
	var file := File.new()

	file.open("user://FishyTracker/fish_log_slot_%s.dat" % save_slot, File.READ)
	if file.is_open():
		var json := JSON.parse(file.get_as_text())

		if json.error != OK:
			push_warning("Could not parse JSON from fish logs file")
			catch_journal = {}
			fish_log = []

		catch_journal = json.result.catch_journal
		fish_log = json.result.fish_log
	else:
		push_warning("Could not open fish logs file for slot %s" % save_slot)
		catch_journal = {}
		fish_log = []
	file.close()

	_fish_log_refs = []
	for entry in fish_log:
		_fish_log_refs.append(entry.ref)

	for fish in catch_journal:
		if typeof(catch_journal[fish]) == TYPE_REAL:
			catch_journal[fish] = int(catch_journal[fish])

	_last_inventory_size = 0


func _switch_save_slot() -> void:
	var save_slot: int = UserSave.current_loaded_slot

	_load_fish_logs(save_slot)


func _set_nullifier(_v) -> void:
	return
