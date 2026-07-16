class_name ItemSystem
extends RefCounted

const AchievementSystemScript = preload("res://scripts/achievement_system.gd")

const MAX_ITEM_ENTRIES := 128
const MAX_STACK := 999
const MAX_MATERIAL_COUNT := 99999
const QUALITY_NAMES := ["凡品", "良品", "上品", "珍品", "道品"]

const ITEMS := {
	"healing_pill": {"name": "回春丹", "category": "consumable", "stackable": true,
		"description": "恢复四成最大气血。", "effect": "heal", "power": 40},
	"spirit_pill": {"name": "聚灵丹", "category": "consumable", "stackable": true,
		"description": "恢复五成最大灵力。", "effect": "mana", "power": 50},
	"cultivation_pill": {"name": "凝元丹", "category": "consumable", "stackable": true,
		"description": "化开一段稳定修为。", "effect": "exp", "power": 120},
	"longevity_pill": {"name": "延年丹", "category": "consumable", "stackable": true,
		"description": "延长八年寿元。", "effect": "lifespan", "power": 8},
	"spirit_herb": {"name": "月华草", "category": "material", "stackable": true},
	"black_iron": {"name": "玄铁矿", "category": "material", "stackable": true},
	"star_sand": {"name": "星砂", "category": "material", "stackable": true},
	"void_crystal": {"name": "虚晶", "category": "material", "stackable": true},
	"fate_thread": {"name": "因果丝", "category": "material", "stackable": true, "persistent": true},
	"iron_sword": {"name": "青铁剑", "category": "weapon", "slot": "weapon", "stackable": false,
		"bonuses": {"attack": 8}},
	"cloud_robe": {"name": "流云袍", "category": "armor", "slot": "armor", "stackable": false,
		"bonuses": {"defense": 6, "max_hp": 45}},
	"jade_qingxiao": {"name": "青霄问心剑", "category": "weapon", "slot": "weapon",
		"stackable": false, "persistent": true, "bonuses": {"attack": 8, "dao_heart": 2}},
	"black_white_jade": {"name": "黑白轮回玉", "category": "relic", "slot": "relic",
		"stackable": false, "persistent": true, "bonuses": {}},
}

const RECIPES := {
	"spirit_blade": {"name": "铸造灵锋", "item_name": "自铸灵锋", "slot": "weapon",
		"cost": {"black_iron": 4, "spirit_herb": 2}, "spirit_stones": 8,
		"base_bonuses": {"attack": 12, "dao_heart": 1}},
	"warding_armor": {"name": "炼制护心甲", "item_name": "自炼护心甲", "slot": "armor",
		"cost": {"black_iron": 3, "star_sand": 2}, "spirit_stones": 10,
		"base_bonuses": {"defense": 9, "max_hp": 70}},
	"void_relic": {"name": "凝结虚痕佩", "item_name": "虚痕佩", "slot": "relic",
		"cost": {"void_crystal": 2, "fate_thread": 1}, "spirit_stones": 18,
		"base_bonuses": {"attack": 3, "defense": 3, "dao_heart": 3}},
}


static func normalize(state: Dictionary) -> Dictionary:
	var inventory_value: Variant = state.get("inventory", {})
	var inventory: Dictionary = inventory_value.duplicate(true) if inventory_value is Dictionary else {}
	var source_items: Variant = inventory.get("items", [])
	var items: Array = []
	var stack_indices := {}
	if source_items is Array:
		for entry_value in source_items:
			if items.size() >= MAX_ITEM_ENTRIES or not entry_value is Dictionary:
				continue
			var entry := _normalize_entry(entry_value as Dictionary)
			if entry.is_empty():
				continue
			var item_id := str(entry.item_id)
			if bool(entry.stackable) and stack_indices.has(item_id):
				var existing_index := int(stack_indices[item_id])
				var existing: Dictionary = items[existing_index]
				existing["quantity"] = mini(MAX_STACK, int(existing.quantity) + int(entry.quantity))
				items[existing_index] = existing
			else:
				if bool(entry.stackable):
					stack_indices[item_id] = items.size()
				items.append(entry)

	var materials := {}
	var material_value: Variant = inventory.get("materials", {})
	if material_value is Dictionary:
		for material_id_value in (material_value as Dictionary).keys():
			var material_id := str(material_id_value)
			if _category(material_id) == "material":
				materials[material_id] = clampi(int((material_value as Dictionary)[material_id_value]), 0, MAX_MATERIAL_COUNT)

	var equipped_value: Variant = inventory.get("equipped", {})
	var equipped: Dictionary = equipped_value.duplicate(true) if equipped_value is Dictionary else {}
	for slot in ["weapon", "armor", "relic"]:
		var key := "%s_id" % slot
		var reference := str(equipped.get(key, "black_white_jade" if slot == "relic" else ""))
		if not reference.is_empty() and not _reference_is_equippable(items, reference, slot):
			if not (slot == "relic" and reference == "black_white_jade"):
				reference = ""
		equipped[key] = reference
	inventory["items"] = items
	inventory["materials"] = materials
	inventory["equipped"] = equipped
	inventory["forge_counter"] = clampi(int(inventory.get("forge_counter", 0)), 0, 1000000)
	inventory["lost_artifacts"] = _bounded_array(inventory.get("lost_artifacts", []), 64)
	state["inventory"] = inventory
	return inventory


static func add_item(state: Dictionary, item_id: String, quantity: int = 1,
		metadata: Dictionary = {}) -> Dictionary:
	normalize(state)
	if quantity <= 0:
		return {"ok": false, "code": "invalid_quantity"}
	if _category(item_id) == "material":
		var inventory: Dictionary = state.inventory
		var materials: Dictionary = inventory.materials
		var accepted := mini(quantity, MAX_MATERIAL_COUNT - int(materials.get(item_id, 0)))
		if accepted <= 0:
			return {"ok": false, "code": "material_full"}
		materials[item_id] = int(materials.get(item_id, 0)) + accepted
		inventory["materials"] = materials
		state["inventory"] = inventory
		return {"ok": true, "code": "material_added", "item_id": item_id, "quantity": accepted}
	if not ITEMS.has(item_id) and metadata.is_empty():
		return {"ok": false, "code": "unknown_item"}
	var inventory: Dictionary = state.inventory
	var items: Array = inventory.items
	var definition: Dictionary = ITEMS.get(item_id, {})
	var stackable := bool(definition.get("stackable", false))
	if stackable:
		for index in range(items.size()):
			var entry: Dictionary = items[index]
			if str(entry.item_id) == item_id:
				var accepted := mini(quantity, MAX_STACK - int(entry.quantity))
				if accepted <= 0:
					return {"ok": false, "code": "stack_full"}
				entry["quantity"] = int(entry.quantity) + accepted
				items[index] = entry
				inventory["items"] = items
				state["inventory"] = inventory
				return {"ok": true, "code": "stacked", "item_id": item_id, "quantity": accepted}
	if items.size() >= MAX_ITEM_ENTRIES:
		return {"ok": false, "code": "inventory_full"}
	var instance_id := str(metadata.get("instance_id", ""))
	if instance_id.is_empty():
		if stackable:
			instance_id = item_id
		else:
			var instance_counter := int(inventory.get("instance_counter", 0)) + 1
			inventory["instance_counter"] = instance_counter
			instance_id = "item_%s_%06d" % [item_id, instance_counter]
	var entry := {
		"item_id": item_id,
		"instance_id": instance_id,
		"quantity": mini(MAX_STACK, quantity) if stackable else 1,
		"stackable": stackable,
	}
	for key in metadata.keys():
		entry[key] = metadata[key]
	items.append(_normalize_entry(entry))
	inventory["items"] = items
	state["inventory"] = inventory
	return {"ok": true, "code": "item_added", "item_id": item_id,
		"instance_id": str(entry.instance_id), "quantity": int(entry.quantity)}


static func count(state: Dictionary, item_id: String) -> int:
	var inventory := normalize(state)
	if _category(item_id) == "material":
		return int((inventory.materials as Dictionary).get(item_id, 0))
	var total := 0
	for entry_value in inventory.items:
		var entry: Dictionary = entry_value
		if str(entry.item_id) == item_id:
			total += int(entry.quantity)
	return total


static func remove_item(state: Dictionary, item_id: String, quantity: int = 1) -> Dictionary:
	var inventory := normalize(state)
	if quantity <= 0 or count(state, item_id) < quantity:
		return {"ok": false, "code": "insufficient_item"}
	if _category(item_id) == "material":
		var materials: Dictionary = inventory.materials
		materials[item_id] = int(materials[item_id]) - quantity
		inventory["materials"] = materials
		state["inventory"] = inventory
		return {"ok": true, "code": "material_removed"}
	var remaining := quantity
	var retained: Array = []
	for entry_value in inventory.items:
		var entry: Dictionary = entry_value
		if str(entry.item_id) == item_id and remaining > 0:
			var taken := mini(remaining, int(entry.quantity))
			entry["quantity"] = int(entry.quantity) - taken
			remaining -= taken
		if int(entry.quantity) > 0:
			retained.append(entry)
	inventory["items"] = retained
	state["inventory"] = inventory
	return {"ok": true, "code": "item_removed"}


static func use_consumable(state: Dictionary, item_id: String) -> Dictionary:
	if _category(item_id) != "consumable" or count(state, item_id) <= 0:
		return {"ok": false, "code": "consumable_unavailable"}
	var player: Dictionary = state.get("player", {})
	var definition: Dictionary = ITEMS[item_id]
	var effect := str(definition.effect)
	var power := int(definition.power)
	if effect == "heal":
		if int(player.get("hp", 0)) >= int(player.get("max_hp", 1)):
			return {"ok": false, "code": "already_full"}
		player["hp"] = mini(int(player.max_hp), int(player.hp) + maxi(1, int(player.max_hp) * power / 100))
	elif effect == "mana":
		if int(player.get("mp", 0)) >= int(player.get("max_mp", 0)):
			return {"ok": false, "code": "already_full"}
		player["mp"] = mini(int(player.max_mp), int(player.mp) + maxi(1, int(player.max_mp) * power / 100))
	elif effect == "exp":
		player["exp"] = int(player.get("exp", 0)) + power
	elif effect == "lifespan":
		player["lifespan"] = int(player.get("lifespan", 1)) + power
	else:
		return {"ok": false, "code": "unsupported_effect"}
	remove_item(state, item_id, 1)
	state["player"] = player
	return {"ok": true, "code": "consumed", "item_id": item_id, "effect": effect, "power": power}


static func equip(state: Dictionary, reference_id: String) -> Dictionary:
	var inventory := normalize(state)
	var entry := _find_entry(inventory.items, reference_id)
	var item_id := reference_id if entry.is_empty() else str(entry.item_id)
	var definition: Dictionary = ITEMS.get(item_id, {})
	var slot := str(entry.get("slot", definition.get("slot", "")))
	if slot not in ["weapon", "armor", "relic"]:
		return {"ok": false, "code": "not_equippable"}
	if entry.is_empty() and item_id != "black_white_jade":
		return {"ok": false, "code": "item_not_owned"}
	var equipped: Dictionary = inventory.equipped
	var key := "%s_id" % slot
	var previous := str(equipped.get(key, ""))
	equipped[key] = reference_id
	inventory["equipped"] = equipped
	state["inventory"] = inventory
	return {"ok": true, "code": "equipped", "slot": slot, "previous": previous, "reference_id": reference_id}


static func effective_stats(state: Dictionary) -> Dictionary:
	var inventory := normalize(state)
	var player: Dictionary = state.get("player", {})
	var result := {
		"attack": int(player.get("attack", 0)), "defense": int(player.get("defense", 0)),
		"max_hp": int(player.get("max_hp", 1)), "max_mp": int(player.get("max_mp", 0)),
		"dao_heart": int(player.get("dao_heart", 0)),
	}
	for slot in ["weapon", "armor", "relic"]:
		var reference := str((inventory.equipped as Dictionary).get("%s_id" % slot, ""))
		if reference.is_empty():
			continue
		var entry := _find_entry(inventory.items, reference)
		var item_id := reference if entry.is_empty() else str(entry.item_id)
		var definition: Dictionary = ITEMS.get(item_id, {})
		var bonuses: Dictionary = entry.get("bonuses", definition.get("bonuses", {}))
		for stat_id in bonuses.keys():
			if result.has(stat_id):
				result[stat_id] = int(result[stat_id]) + int(bonuses[stat_id])
	var jade_bonuses: Dictionary = AchievementSystemScript.effective_bonuses(state)
	for stat_id in jade_bonuses.keys():
		if result.has(stat_id):
			result[stat_id] = int(result[stat_id]) + int(jade_bonuses[stat_id])
	return result


static func can_forge(state: Dictionary, recipe_id: String) -> Dictionary:
	var inventory := normalize(state)
	if not RECIPES.has(recipe_id):
		return {"ok": false, "code": "unknown_recipe"}
	var recipe: Dictionary = RECIPES[recipe_id]
	if (inventory.items as Array).size() >= MAX_ITEM_ENTRIES:
		return {"ok": false, "code": "inventory_full"}
	if int((state.get("player", {}) as Dictionary).get("spirit_stones", 0)) < int(recipe.spirit_stones):
		return {"ok": false, "code": "insufficient_spirit_stones"}
	for material_id in (recipe.cost as Dictionary).keys():
		if int((inventory.materials as Dictionary).get(material_id, 0)) < int(recipe.cost[material_id]):
			return {"ok": false, "code": "insufficient_material", "material_id": material_id}
	return {"ok": true, "code": "ready"}


static func forge(state: Dictionary, recipe_id: String) -> Dictionary:
	var original_state := state.duplicate(true)
	var readiness := can_forge(state, recipe_id)
	if not bool(readiness.ok):
		_restore_state(state, original_state)
		return readiness
	var recipe: Dictionary = RECIPES[recipe_id]
	var inventory: Dictionary = state.inventory
	var player: Dictionary = state.player
	for material_id in (recipe.cost as Dictionary).keys():
		var materials: Dictionary = inventory.materials
		materials[material_id] = int(materials[material_id]) - int(recipe.cost[material_id])
		inventory["materials"] = materials
	player["spirit_stones"] = int(player.spirit_stones) - int(recipe.spirit_stones)
	var creation := int((player.get("path", {}) as Dictionary).get("creation", 0))
	var roll := _roll(state, 1, 100)
	var quality := 0
	var score := roll + creation * 2 + int(player.get("realm_index", 0))
	if score >= 125: quality = 4
	elif score >= 100: quality = 3
	elif score >= 76: quality = 2
	elif score >= 46: quality = 1
	var scale_percent: int = int([100, 120, 145, 175, 220][quality])
	var bonuses := {}
	for stat_id in (recipe.base_bonuses as Dictionary).keys():
		bonuses[stat_id] = maxi(1, int(recipe.base_bonuses[stat_id]) * scale_percent / 100)
	var counter := int(inventory.get("forge_counter", 0)) + 1
	inventory["forge_counter"] = counter
	state["inventory"] = inventory
	state["player"] = player
	var instance_id := "forge_%s_%06d_%s" % [recipe_id, counter, str(state.get("run_id", "run")).sha256_text().left(6)]
	var metadata := {
		"instance_id": instance_id, "name": "%s·%s" % [QUALITY_NAMES[quality], str(recipe.item_name)],
		"category": str(recipe.slot), "slot": str(recipe.slot), "quality": quality,
		"bonuses": bonuses, "persistent": quality >= 4 and recipe_id == "void_relic",
		"crafted_year": int((state.get("world", {}) as Dictionary).get("year", 1)),
	}
	var added := add_item(state, "forged_%s" % recipe_id, 1, metadata)
	if not bool(added.ok):
		_restore_state(state, original_state)
		return {"ok": false, "code": "forge_inventory_failure"}
	return {"ok": true, "code": "forged", "recipe_id": recipe_id, "instance_id": instance_id,
		"quality": quality, "quality_name": QUALITY_NAMES[quality], "bonuses": bonuses, "roll": roll}


static func apply_reincarnation(state: Dictionary) -> Dictionary:
	var inventory := normalize(state)
	var retained: Array = []
	var lost: Array = []
	for entry_value in inventory.items:
		var entry: Dictionary = entry_value
		var definition: Dictionary = ITEMS.get(str(entry.item_id), {})
		if bool(entry.get("persistent", definition.get("persistent", false))):
			retained.append(entry)
		else:
			lost.append({"item_id": str(entry.item_id), "name": display_name(entry), "quantity": int(entry.quantity)})
	var materials: Dictionary = inventory.materials
	var retained_materials := {}
	for material_id in materials.keys():
		if bool((ITEMS.get(str(material_id), {}) as Dictionary).get("persistent", false)):
			retained_materials[material_id] = int(materials[material_id])
		else:
			var trace_count := int(int(materials[material_id]) / 5.0)
			if trace_count > 0:
				retained_materials[material_id] = trace_count
	inventory["items"] = retained
	inventory["materials"] = retained_materials
	inventory["equipped"] = {"weapon_id": "", "armor_id": "", "relic_id": "black_white_jade"}
	var history: Array = inventory.get("lost_artifacts", [])
	for lost_entry in lost:
		history.append(lost_entry)
	inventory["lost_artifacts"] = _bounded_array(history, 64)
	state["inventory"] = inventory
	return {"ok": true, "code": "reincarnation_inventory_applied", "retained": retained.size(), "lost": lost}


static func display_name(entry: Dictionary) -> String:
	return str(entry.get("name", (ITEMS.get(str(entry.get("item_id", "")), {}) as Dictionary).get("name", "无名器物")))


static func _normalize_entry(source: Dictionary) -> Dictionary:
	var item_id := str(source.get("item_id", source.get("id", ""))).left(64)
	var definition: Dictionary = ITEMS.get(item_id, {})
	var forged := item_id.begins_with("forged_") and source.get("bonuses", null) is Dictionary
	if definition.is_empty() and not forged:
		return {}
	var stackable := bool(definition.get("stackable", false))
	var entry := {
		"item_id": item_id,
		"instance_id": str(source.get("instance_id", item_id)).left(96),
		"quantity": clampi(int(source.get("quantity", 1)), 1, MAX_STACK) if stackable else 1,
		"stackable": stackable,
	}
	if forged:
		entry["name"] = str(source.get("name", "自铸器物")).left(64)
		entry["category"] = str(source.get("category", "weapon")).left(24)
		entry["slot"] = str(source.get("slot", "weapon"))
		entry["quality"] = clampi(int(source.get("quality", 0)), 0, 4)
		entry["bonuses"] = _normalize_bonuses(source.get("bonuses", {}))
		entry["persistent"] = bool(source.get("persistent", false))
		entry["crafted_year"] = maxi(1, int(source.get("crafted_year", 1)))
	return entry


static func _normalize_bonuses(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for stat_id in ["attack", "defense", "max_hp", "max_mp", "dao_heart"]:
			if (value as Dictionary).has(stat_id):
				result[stat_id] = clampi(int((value as Dictionary)[stat_id]), -10000, 10000)
	return result


static func _find_entry(items: Array, reference_id: String) -> Dictionary:
	for entry_value in items:
		var entry: Dictionary = entry_value
		if str(entry.instance_id) == reference_id or (bool(entry.stackable) and str(entry.item_id) == reference_id):
			return entry
	return {}


static func _reference_is_equippable(items: Array, reference_id: String, slot: String) -> bool:
	if reference_id == "black_white_jade" and slot == "relic":
		return true
	var entry := _find_entry(items, reference_id)
	if entry.is_empty():
		return false
	var definition: Dictionary = ITEMS.get(str(entry.item_id), {})
	return str(entry.get("slot", definition.get("slot", ""))) == slot


static func _category(item_id: String) -> String:
	return str((ITEMS.get(item_id, {}) as Dictionary).get("category", ""))


static func _roll(state: Dictionary, minimum: int, maximum: int) -> int:
	var cursor := int(state.get("rng_cursor", 0))
	var seed_value := (int(state.get("world_seed", 1)) + cursor * 104729 + 0x4f1bbcdc) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state["rng_cursor"] = cursor + 1
	return rng.randi_range(minimum, maximum)


static func _bounded_array(value: Variant, maximum: int) -> Array:
	var result: Array = value.duplicate(true) if value is Array else []
	while result.size() > maximum:
		result.pop_front()
	return result


static func _restore_state(state: Dictionary, snapshot: Dictionary) -> void:
	state.clear()
	for key in snapshot.keys():
		state[key] = snapshot[key]
