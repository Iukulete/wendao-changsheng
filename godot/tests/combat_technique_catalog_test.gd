extends SceneTree

const CatalogScript = preload("res://scripts/combat_technique_catalog.gd")

var failures: Array[String] = []


func _init() -> void:
	var validation: Dictionary = CatalogScript.validate_definitions()
	_expect(bool(validation.get("ok", false)), "战技目录必须通过完整结构校验")
	_expect(int(validation.get("technique_count", 0)) >= 36,
		"六条道途需要足量的基础与装备战技")
	var path_counts_value: Variant = validation.get("path_counts", {})
	var path_counts: Dictionary = path_counts_value if path_counts_value is Dictionary else {}
	for path_id in CatalogScript.PATH_IDS:
		_expect(int(path_counts.get(path_id, 0)) >= 4,
			"每条道途至少需要四招：%s" % path_id)

	var definitions: Dictionary = CatalogScript.load_definitions()
	var ids := {}
	for value in (definitions.get("techniques", []) as Array):
		var technique: Dictionary = value
		var technique_id := str(technique.get("id", ""))
		_expect(not ids.has(technique_id), "战技 ID 不得重复：%s" % technique_id)
		ids[technique_id] = true
		for required_field in ["id", "name", "path", "timing", "base_action", "cost", "tags", "effects", "cue",
			"description", "ai_weights"]:
			_expect(technique.has(required_field), "战技缺少必填字段：%s.%s" % [technique_id, required_field])

	var tied_player := {"path": {}}
	var empty_inventory := {"equipped": {"weapon_id": "", "armor_id": "", "relic_id": ""}}
	var base_slots_a: Array = CatalogScript.build_slots(tied_player, empty_inventory)
	var base_slots_b: Array = CatalogScript.build_slots(tied_player.duplicate(true), empty_inventory.duplicate(true))
	_expect(base_slots_a == base_slots_b, "相同道途与装备必须生成完全一致的三个槽位")
	_expect(base_slots_a.size() == 3 and _slot_order(base_slots_a) == "pressure|guard|turn",
		"普通战斗必须稳定生成压制、守势、转机三个差异槽位")
	_expect(_all_path(base_slots_a, "insight"), "空道途与旧存档必须稳定回落到明悟构筑")

	var malformed_slots_a: Array = CatalogScript.slots_for_state({"player": {"path": "old"}, "inventory": "old"})
	var malformed_slots_b: Array = CatalogScript.slots_for_state({"player": {"path": "old"}, "inventory": "old"})
	_expect(malformed_slots_a == malformed_slots_b and malformed_slots_a.size() == 3,
		"旧存档的缺失或错误装备结构必须得到稳定默认，不得随机或崩溃")

	var weapon_slots: Array = CatalogScript.build_slots(tied_player,
		{"equipped": {"weapon_id": "old_sword", "armor_id": "", "relic_id": ""}})
	var armor_slots: Array = CatalogScript.build_slots(tied_player,
		{"equipped": {"weapon_id": "", "armor_id": "old_robe", "relic_id": ""}})
	var relic_slots: Array = CatalogScript.build_slots(tied_player,
		{"equipped": {"weapon_id": "", "armor_id": "", "relic_id": "black_white_jade"}})
	var full_slots: Array = CatalogScript.build_slots(tied_player,
		{"equipped": {"weapon_id": "old_sword", "armor_id": "old_robe", "relic_id": "black_white_jade"}})
	_expect(_id_signature(base_slots_a) != _id_signature(weapon_slots) and
		_id_signature(base_slots_a) != _id_signature(armor_slots) and
		_id_signature(base_slots_a) != _id_signature(relic_slots),
		"武器、护甲与灵物构筑都必须改变可用战技，而非只追加数值")
	_expect(_changed_slot_count(base_slots_a, full_slots) == 3,
		"全装备构筑必须让三类战技槽都产生可见差异")
	_expect(_has_tag(weapon_slots[0], "weapon") and _has_tag(armor_slots[1], "armor") and
		_has_tag(relic_slots[2], "relic"),
		"装备替换后的战技必须带有可供界面与规则读取的来源标签")
	_expect(CatalogScript.effect_tags(weapon_slots[0]).has("effect:damage") and
		CatalogScript.effect_tags(armor_slots[1]).has("effect:block") and
		CatalogScript.effect_tags(relic_slots[2]).has("effect:mp"),
		"三类装备槽必须呈现不同的效果职责")
	for value in full_slots:
		var technique: Dictionary = value
		var execution_value: Variant = technique.get("execution", {})
		var execution: Dictionary = execution_value if execution_value is Dictionary else {}
		_expect(not execution.is_empty() and
			str(execution.get("base_action", "")) == str(technique.get("base_action", "")) and
			str(execution.get("cost_resource", "")) == "mp" and
			execution.get("effects", {}) == technique.get("effects", {}),
			"每个槽位必须携带可直接接入 CombatSystem 的动作与效果载荷")

	var ambition_player := {"path": {"ambition": 9, "insight": 1}}
	var compassion_player := {"path": {"compassion": 9, "insight": 1}}
	_expect(_all_path(CatalogScript.build_slots(ambition_player, empty_inventory), "ambition") and
		_all_path(CatalogScript.build_slots(compassion_player, empty_inventory), "compassion") and
		_id_signature(CatalogScript.build_slots(ambition_player, empty_inventory)) !=
		_id_signature(CatalogScript.build_slots(compassion_player, empty_inventory)),
		"主道变化必须切换完整战技构筑")

	var invalid_data := definitions.duplicate(true)
	var invalid_techniques: Array = invalid_data.techniques
	var invalid_technique: Dictionary = invalid_techniques[0]
	var invalid_effects: Dictionary = invalid_technique.effects
	invalid_effects["summon_clone"] = 1
	invalid_technique["effects"] = invalid_effects
	invalid_techniques[0] = invalid_technique
	invalid_data["techniques"] = invalid_techniques
	var invalid_result: Dictionary = CatalogScript.validate_definitions(invalid_data)
	_expect(not bool(invalid_result.get("ok", true)) and
		str(invalid_result.get("code", "")) == "unsupported_technique_effect",
		"目录必须拒绝未声明的效果原语")

	if failures.is_empty():
		print("COMBAT_TECHNIQUE_CATALOG_TEST_OK: schema, six paths, deterministic slots and equipment variants passed")
		quit(0)
	else:
		for failure in failures:
			push_error("COMBAT_TECHNIQUE_CATALOG_TEST_FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _slot_order(slots: Array) -> String:
	var values: Array[String] = []
	for value in slots:
		values.append(str((value as Dictionary).get("slot", "")))
	return "|".join(values)


func _id_signature(slots: Array) -> String:
	var values: Array[String] = []
	for value in slots:
		values.append(str((value as Dictionary).get("id", "")))
	return "|".join(values)


func _all_path(slots: Array, path_id: String) -> bool:
	if slots.size() != 3:
		return false
	for value in slots:
		if str((value as Dictionary).get("path", "")) != path_id:
			return false
	return true


func _changed_slot_count(left: Array, right: Array) -> int:
	var changed := 0
	for index in range(mini(left.size(), right.size())):
		if str((left[index] as Dictionary).get("id", "")) != str((right[index] as Dictionary).get("id", "")):
			changed += 1
	return changed


func _has_tag(technique: Dictionary, tag: String) -> bool:
	var tags_value: Variant = technique.get("tags", [])
	return tags_value is Array and (tags_value as Array).has(tag)
