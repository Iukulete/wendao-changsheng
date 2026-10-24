extends RefCounted
## Isolated execution-contract prototype, NOT production code.
## Precondition: the planner validated the exact current-position -> route[index]
## connector and every subsequent edge for the resident's actual clearance.
## Only final destinations use tolerance. No leftover budget crosses a corner.
static func advance(position: Vector3, route: PackedVector3Array, index: int, delta: float, speed: float, final_tolerance: float = 0.22) -> Dictionary:
	var unchanged := {"ok":false,"code":"invalid_input","position":position,"index":index,"arrived":false,"travelled":0.0,"discarded_budget":0.0}
	if not position.is_finite() or not is_finite(delta) or not is_finite(speed) or not is_finite(final_tolerance):
		return unchanged
	if delta < 0.0 or speed < 0.0 or final_tolerance < 0.0 or index < 0 or index > route.size() or route.is_empty():
		return unchanged
	for point in route:
		if not point.is_finite():
			return unchanged
	var budget := delta * speed
	if not is_finite(budget):
		return unchanged
	if index == route.size():
		if position != route[-1] and (final_tolerance == 0.0 or position.distance_to(route[-1]) > final_tolerance):
			return unchanged
		return {"ok":true,"code":"arrived","position":position,"index":index,"arrived":true,"travelled":0.0,"discarded_budget":budget}
	var cursor := index
	# Skip exact duplicates only; an epsilon could silently jump an unvalidated gap.
	while cursor < route.size() - 1 and position == route[cursor]:
		cursor += 1
	var target := route[cursor]
	var distance := position.distance_to(target)
	if not is_finite(distance) or (distance == 0.0 and position != target):
		return unchanged
	var final := cursor == route.size() - 1
	if final and distance <= final_tolerance:
		return {"ok":true,"code":"arrived","position":position,"index":route.size(),"arrived":true,"travelled":0.0,"discarded_budget":budget}
	if budget == 0.0:
		return {"ok":true,"code":"advanced","position":position,"index":cursor,"arrived":false,"travelled":0.0,"discarded_budget":0.0}
	var step := minf(budget,distance)
	var next := target if step >= distance else position.move_toward(target,step)
	var reached := step >= distance
	var arrived := final and (reached or (final_tolerance > 0.0 and next.distance_to(target) <= final_tolerance))
	var next_index := route.size() if arrived else cursor + 1 if reached else cursor
	return {"ok":true,"code":"arrived" if arrived else "advanced","position":next,"index":next_index,"arrived":arrived,"travelled":position.distance_to(next),"discarded_budget":maxf(0.0,budget-step)}
