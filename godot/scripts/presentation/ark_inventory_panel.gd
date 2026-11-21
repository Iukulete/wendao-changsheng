extends CanvasLayer
## Presentation only. Plans are opaque controller-issued snapshots, never inventory.
signal item_requested(id: String, source: Dictionary, destination: Dictionary, session: int, revision: int)
signal close_requested()
signal nearby_box_requested()
signal inspect_requested(resource: String)
signal unavailable_requested(source: String, resource: String)
signal intent_requested(intent: Dictionary)
signal resource_intent_requested(intent: Dictionary)
const TEXT := Color("edece3")
const MUTED := Color("b6c2c1")
const CYAN := Color("96c9cb")
const FILL := Color("172529")
var equipment_card: ItemCard
var item_strips: Dictionary = {}
var item_cards: Dictionary = {}
var item_actions: Dictionary = {}
var item_action_row: HBoxContainer
var resource_action_row: HBoxContainer
var resource_actions: Dictionary = {}
var _resource_selection_revision := 0
var _window_focused := true
var _item_selection: Dictionary = {}
var rod_toast: Label
var rod_toast_time := 0.0
var rod_hint := ""
var overlay: Control
var panel: Panel
var title_label: Label
var save_warning_label: Label
var notice_label: Label
var detail_label: Label
var access_label: Label
var close_button: Button
var nearby_box_button: Button
var columns: HBoxContainer
var box_column: VBoxContainer
var box_title: Label
var grids: Dictionary = {}
var slots: Dictionary = {}
var model: Dictionary = {}
var targets: Dictionary = {}
var _selected_key := ""
var _drag_source_key := ""
var _drop_side := ""
var _card_styles: Dictionary = {}
var _epoch := 0
var _gesture_sequence := 0
var _open := false
var _mode := "bag"
var _font: Font

class InventoryGlyph extends Control:
	# Original pixel construction: common supplies use a 32-unit grid; remaining
	# existing symbols retain their 24-unit silhouettes, centered at integer scale.
	var resource := ""
	var _owned := true
	var _unit := 2.0
	var _origin := Vector2.ZERO
	const EDGE := Color("162324")
	const WOOD := Color("a67b4c")
	const LIGHT := Color("e0c493")
	const TEAL := Color("81b2aa")
	func show_resource(id: String, count: int) -> void:
		if resource!=id:resource=id;queue_redraw()
		_owned=count>0;modulate=Color(1,1,1,1 if _owned else .35)
	func _b(x: float,y: float,w: float,h: float,c: Color) -> void:
		draw_rect(Rect2(_origin+Vector2(x,y)*_unit,Vector2(w,h)*_unit),c)
	func _oval(cx: int,cy: int,rx: int,ry: int,c: Color) -> void:
		for y in range(-ry,ry+1):
			var span:=int(floor(rx*sqrt(maxf(0.0,1.0-float(y*y)/float(ry*ry)))))
			_b(cx-span,cy+y,span*2+1,1,c)
	func _line(a: Vector2i,b: Vector2i,c: Color,width:=1) -> void:
		var steps:=maxi(absi(b.x-a.x),absi(b.y-a.y))
		for n in range(steps+1):
			var at:=Vector2(a).lerp(Vector2(b),float(n)/maxi(1,steps)).round()
			_b(at.x,at.y,width,width,c)
	func _ring(cx: int,cy: int,rx: int,ry: int,thickness: int,c: Color) -> void:
		for y in range(-ry,ry+1):
			var span:=int(floor(rx*sqrt(maxf(0.0,1.0-float(y*y)/float(ry*ry)))))
			if absi(y)>ry-thickness:_b(cx-span,cy+y,span*2+1,1,c)
			else:
				var inner:=int(floor((rx-thickness)*sqrt(maxf(0.0,1.0-float(y*y)/float((ry-thickness)*(ry-thickness))))))
				_b(cx-span,cy+y,maxi(1,span-inner),1,c);_b(cx+inner,cy+y,maxi(1,span-inner),1,c)
	func _draw() -> void:
		var detailed:=resource in ["wood","shellfish","stew_servings","fish","large_fish","rope","crest","rod_basic","rod_light","rod_resilient"]
		var grid:=30.0 if resource.begins_with("rod_") else 32.0 if detailed else 24.0
		_unit=maxf(1.0,floor(minf(size.x,size.y)/grid));_origin=((size-Vector2.ONE*grid*_unit)/2.0).floor()
		match resource:
			"rod_basic","rod_light","rod_resilient":
				var shaft:=LIGHT if resource=="rod_light" else WOOD
				_line(Vector2i(7,26),Vector2i(24,4),EDGE,3)
				_line(Vector2i(8,25),Vector2i(25,3),shaft,2)
				_line(Vector2i(7,26),Vector2i(12,20),Color("70503b"),3)
				for pt in [Vector2i(14,17),Vector2i(19,11)]:_b(pt.x,pt.y,3,1,TEAL if resource=="rod_resilient" else LIGHT)
				_ring(12,24,3,3,1,TEAL if resource=="rod_resilient" else WOOD)
				_line(Vector2i(26,5),Vector2i(27,22),Color("bac5ae"));_b(26,22,2,3,Color("d59a54"))
			"wood":
				_oval(16,27,14,2,Color("102021"))
				for pos in [Vector2i(7,11),Vector2i(7,22),Vector2i(13,16)]:
					_b(pos.x,pos.y-4,15,9,EDGE);_b(pos.x+1,pos.y-3,14,7,Color("765234"));_b(pos.x+2,pos.y-3,12,2,WOOD)
					_b(pos.x+3,pos.y-2,8,1,LIGHT);_b(pos.x+4,pos.y+2,9,1,Color("b28b58"))
					_oval(pos.x,pos.y,4,5,EDGE);_oval(pos.x,pos.y,3,4,LIGHT);_ring(pos.x,pos.y,2,3,1,WOOD);_b(pos.x,pos.y,1,1,Color("74503a"))
				_b(21,7,2,20,Color("5d4a33"));_b(22,8,1,18,LIGHT);_b(20,16,5,2,WOOD)
			"fish":
				_oval(15,16,11,7,EDGE);_oval(15,15,10,5,Color("79aaa6"));_oval(14,13,8,2,LIGHT)
				_line(Vector2i(23,16),Vector2i(29,10),Color("79aaa6"),3);_line(Vector2i(23,16),Vector2i(29,22),Color("79aaa6"),3);_b(8,14,2,2,EDGE)
			"large_fish":
				# Broad, deep body and gold dorsal fin distinguish the size category;
				# no species/rarity badge or external bitmap is invented.
				_oval(14,17,12,9,EDGE);_oval(14,16,11,7,Color("588f96"));_oval(13,13,9,3,Color("afc5b6"))
				_line(Vector2i(23,17),Vector2i(29,8),Color("588f96"),3);_line(Vector2i(23,17),Vector2i(29,26),Color("588f96"),3)
				_line(Vector2i(11,8),Vector2i(19,5),LIGHT,2);_b(13,7,7,3,WOOD);_b(5,14,2,2,EDGE)
				_line(Vector2i(11,20),Vector2i(17,24),LIGHT,2);_b(9,18,9,1,Color("81b2aa"))
			"shellfish":
				_oval(16,24,13,3,Color("102021"));_oval(16,14,14,12,EDGE);_oval(16,13,12,10,Color("a99774"));_oval(15,11,10,8,LIGHT)
				_b(12,21,9,5,WOOD);_b(14,25,5,3,LIGHT)
				for tip in [Vector2i(5,12),Vector2i(7,7),Vector2i(11,4),Vector2i(16,3),Vector2i(21,4),Vector2i(25,7),Vector2i(27,12)]:
					_line(Vector2i(16,26),tip,Color("887757"));_line(Vector2i(15,24),tip-Vector2i(1,0),Color("e4d2ac"))
				_b(14,26,5,2,WOOD);_b(14,25,4,1,LIGHT)
			"stew_servings":
				_oval(16,28,11,2,Color("102021"));_oval(16,21,13,8,EDGE);_oval(16,20,11,7,Color("614b3c"));_oval(16,19,10,5,WOOD)
				_b(7,19,3,4,Color("cba779"));_b(12,26,9,2,Color("745d47"));_oval(16,15,14,5,EDGE);_oval(16,14,12,4,LIGHT);_oval(16,14,10,3,Color("9caa68"))
				_b(7,14,4,2,Color("e5cd9c"));_b(14,12,4,2,Color("dbad72"));_b(21,14,3,2,Color("e9d7b1"));_b(11,16,3,1,Color("496e55"));_b(18,14,2,2,Color("496e55"))
				for x in [10,18,24]:
					_line(Vector2i(x,9),Vector2i(x-2,6),Color("7fa39b"));_line(Vector2i(x-2,6),Vector2i(x,3),Color("b6d0bf"))
			"rope":
				_oval(15,27,13,2,Color("102021"));_ring(14,14,11,12,4,EDGE);_ring(14,13,10,11,3,Color("8c653f"));_ring(13,12,8,9,2,LIGHT);_ring(13,12,5,6,2,WOOD)
				for point in [Vector2i(6,6),Vector2i(4,11),Vector2i(5,18),Vector2i(10,23),Vector2i(18,23),Vector2i(22,17),Vector2i(22,9),Vector2i(17,3)]:_line(point,point+Vector2i(2,2),Color("caaa73"))
				_line(Vector2i(20,18),Vector2i(27,25),EDGE,4);_line(Vector2i(20,18),Vector2i(27,25),LIGHT,2);_line(Vector2i(27,25),Vector2i(23,29),WOOD,2);_b(17,19,7,3,WOOD);_b(18,19,5,1,LIGHT)
			"crest":
				_ring(16,11,7,7,1,Color("a78a5a"));_line(Vector2i(16,3),Vector2i(16,24),TEAL);_line(Vector2i(11,11),Vector2i(21,11),LIGHT)
				_line(Vector2i(4,22),Vector2i(28,22),WOOD,2);_line(Vector2i(6,25),Vector2i(25,25),WOOD,2);_line(Vector2i(10,28),Vector2i(21,28),TEAL)
			"keel_beams":
				for y in [8,14]:
					_b(2,y,20,5,EDGE);_b(3,y,18,3,WOOD);_b(4,y,15,1,LIGHT);_b(3,y+1,3,2,LIGHT);_b(8,y+2,10,1,Color("80603e"))
			"guest_cabin_frames":
				_b(3,9,3,13,WOOD);_b(18,9,3,13,WOOD);_b(4,8,16,3,LIGHT);_b(7,5,10,3,LIGHT);_b(10,2,4,3,LIGHT);_b(5,18,14,2,WOOD)
			"utility_core","tide_relay_cores","pressure_cores","ancient_parts":
				for r in [Rect2(8,2,8,20),Rect2(2,8,20,8),Rect2(5,5,14,14)]:_b(r.position.x,r.position.y,r.size.x,r.size.y,WOOD if resource=="ancient_parts" else TEAL)
				_b(7,7,10,10,EDGE);_b(9,9,6,6,LIGHT)
				if resource=="pressure_cores":_b(11,4,2,7,WOOD);_b(11,13,2,7,WOOD)
				elif resource=="tide_relay_cores":_b(5,11,14,2,LIGHT)
				elif resource=="ancient_parts":_b(10,8,4,8,WOOD)
			"reef_shell_plates":
				for offset in [0,5]:
					_b(3+offset,5+offset,12,8,EDGE);_b(5+offset,4+offset,8,10,TEAL);_b(6+offset,5+offset,6,2,LIGHT)
			"glass_bead":
				_b(9,2,6,3,TEAL);_b(6,5,12,3,TEAL);_b(4,8,16,8,TEAL);_b(6,16,12,3,TEAL);_b(9,19,6,3,TEAL);_b(7,7,4,4,LIGHT);_b(13,14,3,4,Color("527d98"))
			"guest_pass":
				_b(4,2,16,20,EDGE);_b(5,3,14,18,LIGHT);_b(7,6,10,1,WOOD);_b(7,9,8,1,WOOD);_b(12,13,5,5,Color("9a6455"));_b(13,14,3,3,LIGHT)
			"bag":
				_b(8,2,8,3,LIGHT);_b(5,6,14,3,WOOD);_b(3,9,18,12,WOOD);_b(7,12,10,6,LIGHT);_b(10,6,4,8,EDGE)
			"box":
				_b(2,5,20,17,WOOD);_b(3,6,18,2,LIGHT);_b(4,10,2,10,EDGE);_b(18,10,2,10,EDGE);_b(7,10,10,2,LIGHT);_b(7,15,10,2,LIGHT)

class InventorySurface extends Control:
	var kind := "frame"
	func _ready() -> void:resized.connect(queue_redraw)
	func _draw() -> void:
		if size.x<=0 or size.y<=0:return
		var top:=Color("253e40") if kind=="frame" else Color("132728")
		var bottom:=Color("142427") if kind=="frame" else Color("0e1d20")
		for y in range(0,int(size.y),4):draw_rect(Rect2(0,y,size.x,4),top.lerp(bottom,float(y)/maxf(1,size.y)))
		# Low-contrast deterministic lacquer grain, no randomness or noisy shader.
		for y in range(9,int(size.y)-8,13):
			for x in range(10,int(size.x)-10,29):
				var offset:=(x*7+y*3)%11;draw_line(Vector2(x,y+offset),Vector2(minf(size.x-9,x+8),y+offset),Color(0.65,0.74,0.68,.035),1)
		if kind=="frame":
			draw_rect(Rect2(1,1,size.x-2,size.y-2),Color("756248"),false,2)
			draw_rect(Rect2(5,5,size.x-10,size.y-10),Color("3c5857"),false,1)
			draw_rect(Rect2(4,4,size.x-8,48),Color(.29,.23,.17,.24));draw_line(Vector2(12,54),Vector2(size.x-12,54),Color("6f6952"),1)
			for p in [Vector2(3,3),Vector2(size.x-3,3),Vector2(3,size.y-3),Vector2(size.x-3,size.y-3)]:
				var dx:=1 if p.x<size.x/2 else -1;var dy:=1 if p.y<size.y/2 else -1
				draw_line(p,p+Vector2(dx*18,0),Color("9b8158"),2);draw_line(p,p+Vector2(0,dy*18),Color("9b8158"),2)
				draw_rect(Rect2(p+Vector2(dx*6-1,dy*6-1),Vector2(2,2)),Color("ccb080"))
		else:
			for n in 3:
				var points:=PackedVector2Array()
				for x in range(0,100,4):points.append(Vector2(size.x-112+x,size.y-20-n*8+sin(float(x)/13.0)*3))
				draw_polyline(points,Color(.40,.63,.61,.10),1)

class InventorySlot extends PanelContainer:
	var ui
	var owner_id := ""
	var row: Dictionary = {}
	var text_label: Label
	var name_label: Label
	var glyph: InventoryGlyph
	var _hovered := false
	var _armed := false
	var _drag_started := false
	var _button := MOUSE_BUTTON_NONE
	var _press_epoch := -1
	var _press_resource := ""
	var _press_label := ""
	var _press_count := 0
	var _gesture := 0
	var _press_plan: Dictionary = {}
	func initialize(parent_ui, side: String) -> void:
		ui=parent_ui;owner_id=side
		mouse_filter=Control.MOUSE_FILTER_STOP
		focus_mode=Control.FOCUS_NONE
		custom_minimum_size=Vector2(176,76);size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var stack:=VBoxContainer.new();stack.mouse_filter=Control.MOUSE_FILTER_IGNORE;stack.add_theme_constant_override("separation",3);stack.size_flags_vertical=Control.SIZE_SHRINK_CENTER;add_child(stack)
		var identity:=HBoxContainer.new();identity.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity.add_theme_constant_override("separation",8);stack.add_child(identity)
		glyph=InventoryGlyph.new();glyph.custom_minimum_size=Vector2(32,32);glyph.size_flags_vertical=Control.SIZE_SHRINK_CENTER;glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity.add_child(glyph)
		name_label=ui._label(16);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;name_label.size_flags_vertical=Control.SIZE_SHRINK_CENTER;identity.add_child(name_label)
		text_label=ui._label(16);stack.add_child(text_label)
		mouse_entered.connect(func():_hovered=true;refresh_visual())
		mouse_exited.connect(func():_hovered=false;refresh_visual();ui._leave_drop_side(owner_id))
	func display(data: Dictionary) -> void:
		row=data.duplicate(true)
		custom_minimum_size.y=76 if ui._mode=="chest" else 56
		var count:=int(row.get("count",0))
		var all_plan:Dictionary=row.get("plan_all",{})
		var line:="点选查看用途"
		if ui._mode=="chest":
			var amount:=int(all_plan.get("amount",0))
			line="%s %d · 留下 %d" % ["存入" if owner_id=="player" else "取出",amount,maxi(0,count-amount)]
			if amount<=0:line=str(row.get("summary",row.get("locked_reason","不可转移")))
		name_label.text="%s ×%d" % [str(row.get("label",row.get("id",""))),count]
		text_label.text=line;text_label.visible=ui._mode=="chest";glyph.show_resource(str(row.get("id","")),count)
		name_label.add_theme_color_override("font_color",TEXT if count>0 else MUTED)
		text_label.add_theme_color_override("font_color",MUTED)
		tooltip_text=str(row.get("description",""))
		if not str(row.get("locked_reason","")).is_empty():tooltip_text+="\n"+str(row.locked_reason)
		refresh_visual()
	func refresh_visual() -> void:
		var key:=owner_id+":"+str(row.get("id",""))
		add_theme_stylebox_override("panel",ui._card_style(_hovered,ui._selected_key==key,ui._drag_source_key==key))
		glyph.modulate.a=(1.0 if int(row.get("count",0))>0 else .35)*(.65 if ui._drag_source_key==key else 1.0)
	func disarm() -> void:
		_armed=false;_press_plan.clear()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			accept_event()
			if event.pressed:
				_armed=true;_drag_started=false;_button=event.button_index;_press_epoch=ui._epoch
				_press_resource=str(row.get("id",""));_press_label=str(row.get("label",_press_resource));_press_count=int(row.get("count",0));ui._gesture_sequence+=1;_gesture=ui._gesture_sequence
				_press_plan=(row.get("plan_all",{}) if _button==MOUSE_BUTTON_LEFT else row.get("plan_one",{})).duplicate(true)
			else:
				var allowed:bool=_armed and not _drag_started and _button==event.button_index and _press_epoch==ui._epoch and Rect2(Vector2.ZERO,size).has_point(event.position)
				var plan:=_press_plan.duplicate(true);var resource:=_press_resource
				plan["gesture_id"]=_gesture
				disarm()
				if allowed and ui._open:
					ui._select_visual(owner_id+":"+resource)
					ui.inspect_requested.emit(resource)
					if ui._mode=="chest":
						if int(plan.get("amount",0))>0:ui.intent_requested.emit(plan)
						else:ui.unavailable_requested.emit(owner_id,resource)
	func _get_drag_data(_at: Vector2) -> Variant:
		if not _armed or ui._mode!="chest" or not ui._open or _press_epoch!=ui._epoch:return null
		# Even an unavailable drag attempt is not a click on later release.
		_drag_started=true
		if _press_plan.is_empty() or int(_press_plan.get("amount",0))<=0:return null
		ui._set_drag_visual(owner_id+":"+_press_resource)
		var preview:=PanelContainer.new();preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		preview.add_theme_stylebox_override("panel",ui._card_style(false,true,false))
		var label:=Label.new();label.text="%s\n转移 %d · 留下 %d" % [_press_label,int(_press_plan.amount),maxi(0,_press_count-int(_press_plan.amount))]
		label.add_theme_font_override("font",ui._font);label.add_theme_font_size_override("font_size",18);label.add_theme_color_override("font_color",TEXT)
		var preview_row:=HBoxContainer.new();preview_row.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview.add_child(preview_row)
		var preview_glyph:=InventoryGlyph.new();preview_glyph.custom_minimum_size=Vector2(64,64);preview_glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview_glyph.show_resource(_press_resource,_press_count);preview_row.add_child(preview_glyph);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview_row.add_child(label)
		set_drag_preview(preview)
		var frozen:=_press_plan.duplicate(true);frozen["gesture_id"]=_gesture
		return {"panel_id":ui.get_instance_id(),"epoch":_press_epoch,"source":owner_id,"intent":frozen}
	func _can_drop_data(_at: Vector2,data: Variant) -> bool:
		var allowed: bool=ui._accepts(owner_id,data);ui._show_drop_side(owner_id if allowed else "");return allowed
	func _drop_data(_at: Vector2,data: Variant) -> void:ui._drop(owner_id,data)
	func _notification(what: int) -> void:
		if what==NOTIFICATION_DRAG_END:disarm();ui._clear_drag_visuals()

class ItemCard extends PanelContainer:
	# Entity cards select only. Transactions belong to explicit footer actions.
	var ui
	var row: Dictionary = {}
	var source := ""
	var caption: Label
	var glyph: InventoryGlyph
	var button_armed: Dictionary = {}
	var _hovered := false
	func initialize(parent_ui) -> void:
		ui=parent_ui;mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL
		custom_minimum_size=Vector2(110,44);size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var line:=HBoxContainer.new();line.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_theme_constant_override("separation",6);add_child(line)
		glyph=InventoryGlyph.new();glyph.custom_minimum_size=Vector2(32,32);glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;line.add_child(glyph)
		caption=ui._label(16);caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_OFF;caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;line.add_child(caption)
		mouse_entered.connect(func():_hovered=true;refresh_visual())
		mouse_exited.connect(func():_hovered=false;disarm();refresh_visual())
		focus_exited.connect(func():disarm();refresh_visual())
		focus_entered.connect(refresh_visual)
	func display(data: Dictionary, from: String) -> void:
		if row.get("id","")!=data.get("id","") or row.get("address",{})!=data.get("address",{}) or source!=from:disarm()
		row=data.duplicate(true);source=from
		if not button_armed.is_empty() and not ui._item_snapshot_current(button_armed):disarm()
		var id:=str(row.get("id",""));var profile:=str(row.get("profile",""))
		glyph.visible=not id.is_empty();glyph.show_resource(profile if profile.begins_with("rod_") else "rod_"+profile,1)
		caption.text=("当前工具 · " if source=="equipment" else "")+str(row.get("title","未装备"))
		if id.is_empty():caption.text="当前工具 · 未装备"
		tooltip_text="未装备工具。选择随身钓竿，再点击下方「装备」。" if id.is_empty() else str(row.get("title",""))+" · "+str(row.get("hint",""))+"\n点击选择，在下方选择操作；不拖拽。"
		focus_mode=Control.FOCUS_ALL if not id.is_empty() else Control.FOCUS_NONE
		refresh_visual()
	func refresh_visual() -> void:
		var selected:bool=not row.is_empty() and str(ui._item_selection.get("id",""))==str(row.get("id","")) and ui._item_selection.get("source",{})==row.get("address",{})
		var style:StyleBoxFlat=ui._button_style(_hovered or has_focus() or selected)
		if selected:style.border_color=CYAN
		style.content_margin_top=4;style.content_margin_bottom=4;style.content_margin_left=8;style.content_margin_right=8
		add_theme_stylebox_override("panel",style)
	func disarm() -> void:button_armed.clear()
	func _arm(kind: String) -> void:
		disarm()
		if not ui._open or str(row.get("id","")).is_empty():return
		button_armed=ui._item_snapshot(row);button_armed["kind"]=kind
	func _release(kind: String, inside: bool) -> void:
		var frozen:=button_armed.duplicate(true);disarm()
		if frozen.is_empty() or frozen.get("kind","")!=kind or not inside or not ui._item_snapshot_current(frozen):return
		ui._choose_item(row)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			accept_event()
			if event.pressed:
				grab_focus()
				if event.double_click:disarm()
				else:_arm("mouse")
			else:_release("mouse",Rect2(Vector2.ZERO,size).has_point(event.position))
		elif event is InputEventKey and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			accept_event()
			if event.echo:return
			if event.pressed:_arm("key_"+str(event.keycode))
			else:_release("key_"+str(event.keycode),has_focus())

class ItemAction extends Button:
	var ui
	var action := ""
	var destination: Dictionary = {}
	var button_armed: Dictionary = {}
	func initialize(parent_ui, id: String, title: String, address: Dictionary) -> void:
		ui=parent_ui;action=id;text=title;destination=address.duplicate(true)
		name="ItemAction_"+id;custom_minimum_size=Vector2(76,36);focus_mode=Control.FOCUS_ALL
		add_theme_font_override("font",ui._font);add_theme_font_size_override("font_size",16)
		add_theme_stylebox_override("normal",ui._button_style());add_theme_stylebox_override("hover",ui._button_style(true));add_theme_stylebox_override("focus",ui._button_style(true))
		mouse_exited.connect(disarm);focus_exited.connect(disarm)
	func disarm() -> void:button_armed.clear();set_pressed_no_signal(false)
	func _arm(kind: String) -> void:
		disarm()
		if disabled or not is_visible_in_tree() or not ui._item_snapshot_current(ui._item_selection):return
		button_armed=ui._item_selection.duplicate(true)
		button_armed["action"]=action;button_armed["destination"]=destination.duplicate(true);button_armed["kind"]=kind
	func _release(kind: String, inside: bool) -> void:
		var frozen:=button_armed.duplicate(true);disarm()
		if frozen.is_empty() or frozen.get("kind","")!=kind or not inside or disabled or not is_visible_in_tree():return
		if not ui._item_snapshot_current(frozen) or not ui._item_snapshot_current(ui._item_selection):return
		if frozen.get("id","")!=ui._item_selection.get("id","") or frozen.get("source",{})!=ui._item_selection.get("source",{}) or frozen.get("action","")!=action or frozen.get("destination",{})!=destination:return
		ui._disarm_items();ui._item_selection.clear();ui.rod_hint="";ui._refresh_item_actions()
		ui.item_requested.emit(str(frozen.id),frozen.source.duplicate(true),frozen.destination.duplicate(true),int(frozen.session),int(frozen.revision))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			accept_event()
			if event.pressed:
				grab_focus()
				if event.double_click:disarm()
				else:_arm("mouse")
			else:_release("mouse",Rect2(Vector2.ZERO,size).has_point(event.position))
		elif event is InputEventKey and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			accept_event()
			if event.echo:return
			if event.pressed:_arm("key_"+str(event.keycode))
			else:_release("key_"+str(event.keycode),has_focus())

class ResourceAction extends Button:
	# Separate fixed controls: a double-click on arm can never become cancel.
	# Like Items v2 actions, only a matching press/release emits the snapshot.
	var ui
	var value := true
	var field_stew := false
	var button_armed: Dictionary = {}
	func initialize(parent_ui, use_bait: bool, drink: bool = false) -> void:
		ui=parent_ui;value=use_bait;field_stew=drink
		name="ResourceAction_"+("drink_stew" if drink else ("bait" if value else "cancel_bait"))
		text="喝热汤 · 1份" if drink else ("下次用作鱼饵" if value else "取消用饵")
		custom_minimum_size=Vector2(132 if value or drink else 88,36);focus_mode=Control.FOCUS_ALL
		add_theme_font_override("font",ui._font);add_theme_font_size_override("font_size",16)
		add_theme_stylebox_override("normal",ui._button_style());add_theme_stylebox_override("hover",ui._button_style(true));add_theme_stylebox_override("focus",ui._button_style(true))
		mouse_exited.connect(disarm);focus_exited.connect(disarm)
	func disarm() -> void:button_armed.clear();set_pressed_no_signal(false)
	func _arm(kind: String) -> void:
		disarm()
		if disabled or not is_visible_in_tree():return
		var snapshot:Dictionary=ui._field_stew_snapshot() if field_stew else ui._resource_snapshot(value)
		if not ui._resource_snapshot_current(snapshot):return
		button_armed=snapshot;button_armed["kind"]=kind
	func _release(kind: String, inside: bool) -> void:
		var frozen:=button_armed.duplicate(true);disarm()
		if frozen.is_empty() or frozen.get("kind","")!=kind or not inside or disabled or not is_visible_in_tree():return
		frozen.erase("kind")
		if not ui._resource_snapshot_current(frozen):return
		ui._disarm_resources()
		ui.resource_intent_requested.emit(frozen)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			accept_event()
			if event.pressed:
				grab_focus()
				if event.double_click:disarm()
				else:_arm("mouse")
			else:_release("mouse",Rect2(Vector2.ZERO,size).has_point(event.position))
		elif event is InputEventKey and event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			accept_event()
			if event.echo:return
			if event.pressed:_arm("key_"+str(event.keycode))
			else:_release("key_"+str(event.keycode),has_focus())

class InventoryTarget extends PanelContainer:
	var ui
	var owner_id := ""
	func _can_drop_data(_at: Vector2,data: Variant) -> bool:
		var allowed: bool=ui._accepts(owner_id,data);ui._show_drop_side(owner_id if allowed else "");return allowed
	func _drop_data(_at: Vector2,data: Variant) -> void:ui._drop(owner_id,data)

func _card_style(hovered: bool,selected: bool,dragging: bool) -> StyleBoxFlat:
	var key:="%s:%s:%s" % [hovered,selected,dragging]
	if _card_styles.has(key):return _card_styles[key]
	var style:=_style();style.bg_color=Color("2d4745") if hovered else Color("203735")
	if selected:style.bg_color=Color("294541")
	style.border_color=Color("91c3b1") if selected or dragging else Color("789187") if hovered else Color("4a625b")
	style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=5;style.content_margin_bottom=5
	style.border_width_top=1;style.border_width_bottom=1;style.shadow_color=Color(0.01,0.04,0.04,.45);style.shadow_size=2;style.shadow_offset=Vector2(0,2)
	_card_styles[key]=style;return style
func _button_style(hovered:=false) -> StyleBoxFlat:
	var style:=_style();style.bg_color=Color("354843") if hovered else Color("243632");style.border_color=Color("b19b70") if hovered else Color("78674d");style.content_margin_top=4;style.content_margin_bottom=4;return style
func _well_style(active:=false) -> StyleBoxFlat:
	var style:=_style();style.bg_color=Color("112326");style.border_color=Color("90c2b1") if active else Color("47615c")
	style.border_width_top=2;style.border_width_bottom=1;return style
func _select_visual(key: String) -> void:
	_disarm_resources();_resource_selection_revision+=1
	if not key.is_empty():
		_item_selection.clear();_disarm_items();_refresh_item_actions()
	_selected_key=key
	for slot in slots.values():slot.refresh_visual()
	_refresh_resource_actions()
func _set_drag_visual(key: String) -> void:
	_drag_source_key=key
	for slot in slots.values():slot.refresh_visual()
func _show_drop_side(side: String) -> void:
	if _drop_side==side:return
	_drop_side=side
	for target_side in targets:targets[target_side].add_theme_stylebox_override("panel",_well_style(target_side==side))
func _leave_drop_side(side: String) -> void:
	if _drop_side==side:_show_drop_side("")
func _clear_drag_visuals() -> void:
	if _drag_source_key.is_empty() and _drop_side.is_empty():return
	_drag_source_key="";_show_drop_side("")
	for slot in slots.values():slot.refresh_visual()

func _style() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=FILL;s.border_color=Color("587476")
	s.set_border_width_all(1);s.set_corner_radius_all(5);s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=9;s.content_margin_bottom=9
	return s
func _label(size_: int=18) -> Label:
	var l:=Label.new();l.add_theme_font_override("font",_font);l.add_theme_font_size_override("font_size",size_);l.add_theme_color_override("font_color",TEXT);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l
func setup(font: Font) -> void:
	if is_instance_valid(overlay):return
	_font=font;layer=40
	overlay=Control.new();overlay.name="InventoryOverlay";overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay)
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.6);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(shade)
	panel=Panel.new();panel.name="InventoryPanel";panel.mouse_filter=Control.MOUSE_FILTER_STOP;panel.add_theme_stylebox_override("panel",_style());overlay.add_child(panel)
	var surface:=InventorySurface.new();surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);panel.add_child(surface)
	var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",8);panel.add_child(stack);stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);stack.offset_left=12;stack.offset_right=-12;stack.offset_top=9;stack.offset_bottom=-9
	var header:=HBoxContainer.new();stack.add_child(header);title_label=_label(24);title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;var crest:=InventoryGlyph.new();crest.custom_minimum_size=Vector2(32,36);crest.mouse_filter=Control.MOUSE_FILTER_IGNORE;crest.show_resource("crest",1);header.add_child(crest);header.add_child(title_label)
	close_button=Button.new();close_button.name="InventoryClose";close_button.text="× 关闭  Esc";close_button.custom_minimum_size=Vector2(96,36);close_button.focus_mode=Control.FOCUS_NONE;close_button.add_theme_font_override("font",_font);close_button.pressed.connect(_request_close);header.add_child(close_button);close_button.add_theme_stylebox_override("normal",_button_style());close_button.add_theme_stylebox_override("hover",_button_style(true));close_button.add_theme_stylebox_override("pressed",_button_style(true))
	var utility:=HBoxContainer.new();utility.name="InventoryUtility";utility.add_theme_constant_override("separation",10);stack.add_child(utility)
	equipment_card=ItemCard.new();equipment_card.name="ToolEquipmentSlot";equipment_card.initialize(self);utility.add_child(equipment_card)
	nearby_box_button=Button.new();nearby_box_button.name="InventoryNearbyBox";nearby_box_button.text="打开附近本舟储箱";nearby_box_button.focus_mode=Control.FOCUS_NONE;nearby_box_button.add_theme_font_override("font",_font);nearby_box_button.pressed.connect(_request_nearby_box);utility.add_child(nearby_box_button);nearby_box_button.add_theme_stylebox_override("normal",_button_style());nearby_box_button.add_theme_stylebox_override("hover",_button_style(true));nearby_box_button.add_theme_stylebox_override("pressed",_button_style(true))
	rod_toast=_label(17);rod_toast.name="RodSwitchNotice";rod_toast.add_theme_color_override("font_outline_color",Color("132326"));rod_toast.add_theme_constant_override("outline_size",3);rod_toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;rod_toast.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(rod_toast);rod_toast.hide()
	columns=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",16);stack.add_child(columns)
	for side in ["player","box"]:
		var column:=VBoxContainer.new();column.name="Inventory_"+side;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(column)
		var identity:=HBoxContainer.new();identity.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity.add_theme_constant_override("separation",8);column.add_child(identity)
		var symbol:=InventoryGlyph.new();symbol.custom_minimum_size=Vector2(24,24);symbol.size_flags_vertical=Control.SIZE_SHRINK_CENTER;symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE;symbol.show_resource("bag" if side=="player" else "box",1);identity.add_child(symbol)
		var heading:=_label(20);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.size_flags_vertical=Control.SIZE_SHRINK_CENTER;heading.text="随身物品" if side=="player" else "储物箱";identity.add_child(heading)
		if side=="box":box_column=column;box_title=heading
		var strip:=HBoxContainer.new();strip.name="ItemStrip_"+side;strip.add_theme_constant_override("separation",6);item_strips[side]=strip
		var target:=InventoryTarget.new();target.ui=self;target.owner_id=side;target.mouse_filter=Control.MOUSE_FILTER_STOP;target.size_flags_vertical=Control.SIZE_EXPAND_FILL;target.add_theme_stylebox_override("panel",_well_style());column.add_child(target);targets[side]=target
		target.mouse_exited.connect(func():_leave_drop_side(side))
		var well_surface:=InventorySurface.new();well_surface.kind="well";well_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE;target.add_child(well_surface)
		var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.mouse_filter=Control.MOUSE_FILTER_PASS;target.add_child(scroll)
		var grid:=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.mouse_filter=Control.MOUSE_FILTER_PASS;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid);grids[side]=grid
		column.add_child(strip)
	var divider:=HSeparator.new();divider.mouse_filter=Control.MOUSE_FILTER_IGNORE;stack.add_child(divider)
	# This is a read-only projection of the game's persistent save warning,
	# separate from replaceable item feedback. Never clear its authoritative meta.
	save_warning_label=_label(16);save_warning_label.name="InventorySaveWarning";save_warning_label.add_theme_color_override("font_color",Color("f0ada2"));stack.add_child(save_warning_label);save_warning_label.hide()
	notice_label=_label(16);notice_label.add_theme_color_override("font_color",CYAN);stack.add_child(notice_label)
	var details:=HBoxContainer.new();details.add_theme_constant_override("separation",10);stack.add_child(details)
	detail_label=_label(16);detail_label.custom_minimum_size.y=42;detail_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;details.add_child(detail_label)
	item_action_row=HBoxContainer.new();item_action_row.name="ItemActions";item_action_row.size_flags_vertical=Control.SIZE_SHRINK_CENTER;details.add_child(item_action_row)
	for spec in [["equip","装备",{"kind":"slot","owner":"player","slot":"tool"}],["store","存入",{"kind":"container","id":"ark.storage"}],["take","取回",{"kind":"container","id":"player.bag"}],["unequip","卸下",{"kind":"container","id":"player.bag"}]]:
		var action:=ItemAction.new();action.initialize(self,str(spec[0]),str(spec[1]),spec[2]);item_action_row.add_child(action);item_actions[str(spec[0])]=action;action.hide()
	item_action_row.hide()
	resource_action_row=HBoxContainer.new();resource_action_row.name="ResourceActions";resource_action_row.add_theme_constant_override("separation",8);resource_action_row.size_flags_vertical=Control.SIZE_SHRINK_CENTER;details.add_child(resource_action_row)
	for use_bait in [true,false]:
		var action:=ResourceAction.new();action.initialize(self,use_bait);resource_action_row.add_child(action);resource_actions["bait" if use_bait else "cancel_bait"]=action
	var drink:=ResourceAction.new();drink.initialize(self,false,true);resource_action_row.add_child(drink);resource_actions["drink_stew"]=drink;drink.hide()
	resource_action_row.hide()
	access_label=_label(15);access_label.add_theme_color_override("font_color",MUTED);stack.add_child(access_label)
	overlay.resized.connect(_layout);_layout();overlay.hide()
func _layout() -> void:
	if not is_instance_valid(panel) or not is_inside_tree() or get_viewport()==null:return
	var view:=get_viewport().get_visible_rect().size
	var width:=minf(1000 if _mode=="chest" else 880,view.x-32);var height:=minf(600 if _mode=="chest" else (520 if save_warning_label.visible else 480),view.y-32)
	for side in grids:grids[side].columns=3 if _mode=="bag" else 2
	panel.position=Vector2((view.x-width)/2,(view.y-height)/2);panel.size=Vector2(width,height)
func present(data: Dictionary) -> void:
	assert(is_instance_valid(overlay),"setup(font) before present(model)")
	var next_open:=bool(data.get("open",false));var next_mode:=str(data.get("mode","bag"))
	if _open!=next_open or _mode!=next_mode:
		cancel_drag();_item_selection.clear();_select_visual("")
		for slot in slots.values():slot._hovered=false;slot.refresh_visual()
	_open=next_open;_mode=next_mode;model=data.duplicate(true);overlay.visible=_open
	if not _open:
		_disarm_items();_disarm_resources();rod_hint=""
		return
	title_label.text=str(model.get("title","背包"));notice_label.text=("当前 · "+str(model.notice)) if not str(model.get("notice","")).is_empty() else "";detail_label.text="用途 · "+str(model.get("detail","点选物品查看用途；不在这里使用或消耗。"));access_label.text=str(model.get("access_message","左键按实际数量转移 · 右键 1 个 · 拖到对侧转移 · 放到世界/关闭取消"))
	var warning:=str(model.get("save_warning",""))
	save_warning_label.text="未保存 · "+warning if not warning.is_empty() else ""
	save_warning_label.visible=not warning.is_empty()
	# Avoid showing the same failure twice immediately after F5; a later item
	# result still gets its own line and can never replace the persistent warning.
	notice_label.visible=not str(model.get("notice","")).is_empty() and (warning.is_empty() or str(model.get("notice",""))!=warning)
	nearby_box_button.visible=_mode=="bag" and bool(model.get("nearby_box_available",false));nearby_box_button.disabled=not nearby_box_button.visible
	_present_items()

	box_column.visible=_mode=="chest";box_title.text="储物箱 · 食物 %d/%d" % [int(model.get("food_used",0)),int(model.get("food_capacity",8))]
	for side in ["player","box"]:
		var visible_keys:={}
		for data_row in model.get("player_rows" if side=="player" else "box_rows",[]):
			var row:Dictionary=data_row;var key:String=side+":"+str(row.get("id",""));visible_keys[key]=true
			if not slots.has(key):
				var slot:=InventorySlot.new();slot.name="Slot_"+side+"_"+str(row.get("id",""));slot.initialize(self,side);slot.add_theme_stylebox_override("panel",_card_style(false,false,false));slot.text_label.add_theme_font_override("font",_font);slot.text_label.add_theme_color_override("font_color",TEXT);grids[side].add_child(slot);slots[key]=slot
			slots[key].visible=true;slots[key].display(row)
		for key in slots:
			if str(key).begins_with(side+":") and not visible_keys.has(key):
				# A vanished source invalidates the whole mouse gesture before hiding.
				# Keep the owner/resource node identity for later reappearance.
				if slots[key].visible:cancel_drag()
				if _selected_key==key:_select_visual("")
				slots[key]._hovered=false;slots[key].hide()
	_refresh_resource_actions()
	_layout()
func _accepts(side: String,data: Variant) -> bool:
	if not _open or _mode!="chest" or not data is Dictionary:return false
	if data.get("panel_id",0)!=get_instance_id() or data.get("epoch",-1)!=_epoch or data.get("source","")==side:return false
	var intent:Dictionary=data.get("intent",{})
	return not intent.is_empty() and int(intent.get("amount",0))>0 and str(intent.get("destination",""))==side
func _drop(side: String,data: Variant) -> void:
	if not _accepts(side,data):return
	var intent:Dictionary=data.intent.duplicate(true)
	# Invalidate before emitting: a release or repeated drop cannot spend twice.
	_epoch+=1
	for slot in slots.values():slot.disarm()
	_clear_drag_visuals()
	intent_requested.emit(intent)
func cancel_drag() -> void:
	_disarm_items()
	_disarm_resources()
	_epoch+=1
	for slot in slots.values():slot.disarm()
	_clear_drag_visuals()
	if is_inside_tree() and get_viewport().gui_is_dragging():get_viewport().gui_cancel_drag()
func is_dragging() -> bool:return is_inside_tree() and get_viewport().gui_is_dragging()
func _request_close() -> void:
	cancel_drag();close_requested.emit()

func _request_nearby_box() -> void:
	if not _open or _mode!="bag" or not bool(model.get("nearby_box_available",false)):return
	cancel_drag();nearby_box_requested.emit()

func _items_enabled() -> bool:
	return bool(model.get("item_enabled",model.get("rod_enabled",true)))

func _disarm_items() -> void:
	if is_instance_valid(equipment_card):equipment_card.disarm()
	for card in item_cards.values():card.disarm()
	for action in item_actions.values():action.disarm()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused=false;_disarm_items();_disarm_resources();_refresh_resource_actions()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused=true;_refresh_resource_actions()

func _present_items() -> void:
	var equipped:Dictionary=model.get("equipment_slot",{})
	equipment_card.display(equipped,"equipment")
	var shown:Dictionary={};var seen:Dictionary={}
	if not str(equipped.get("id","")).is_empty():seen[str(equipped.id)]=true
	for data_row in model.get("item_rows",[]):
		var row:Dictionary=data_row;var id:=str(row.get("id",""));var location:=str(row.get("location",""))
		if id.is_empty() or seen.has(id) or location not in ["bag","box"]:continue
		seen[id]=true
		if location=="box" and _mode!="chest":continue
		var side:="player" if location=="bag" else "box";var key:=location+":"+id
		shown[key]=true
		if not item_cards.has(key):
			var card:=ItemCard.new();card.name="Item_"+location+"_"+id;card.initialize(self);item_strips[side].add_child(card);item_cards[key]=card
		var card:ItemCard=item_cards[key];card.show()
		card.display(row,location)
	for key in item_cards:
		if not shown.has(key):item_cards[key].disarm();item_cards[key]._hovered=false;item_cards[key].hide()
	for side in item_strips:
		var any_visible:=false
		for card in item_strips[side].get_children():
			if card.visible:any_visible=true
		item_strips[side].visible=any_visible
	if not _item_selection.is_empty() and not _item_snapshot_current(_item_selection):
		_item_selection.clear();_disarm_items()
	rod_hint="";_refresh_item_actions()

func _item_snapshot(row: Dictionary) -> Dictionary:
	var address:Dictionary=row.get("address",{})
	return {"id":str(row.get("id","")),"source":address.duplicate(true),"mode":_mode,"generation":int(model.get("generation",-1)),"session":int(model.get("session",model.get("generation",-1))),"revision":int(model.get("items_revision",-1))}

func _item_snapshot_current(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or not _open or snapshot.get("mode","")!=_mode:return false
	if int(snapshot.get("generation",-2))!=int(model.get("generation",-1)) or int(snapshot.get("session",-2))!=int(model.get("session",model.get("generation",-1))) or int(snapshot.get("revision",-2))!=int(model.get("items_revision",-1)):return false
	var row:=_find_item(str(snapshot.get("id","")))
	return not row.is_empty() and not snapshot.get("source",{}).is_empty() and row.get("address",{})==snapshot.get("source",{})

func _find_item(id: String) -> Dictionary:
	if id.is_empty():return {}
	var equipped:Dictionary=model.get("equipment_slot",{})
	if str(equipped.get("id",""))==id:return equipped
	for row in model.get("item_rows",[]):
		if str(row.get("id",""))==id and (row.get("location","")=="bag" or _mode=="chest"):return row
	return {}

func _choose_item(row: Dictionary) -> void:
	_disarm_resources();_resource_selection_revision+=1
	_disarm_items();_item_selection=_item_snapshot(row);_selected_key="";rod_hint=""
	for slot in slots.values():slot.refresh_visual()
	_refresh_item_actions()

func follow_taken_item(id: String, session: int, revision: int) -> void:
	# This is presentation after a committed BOX -> BAG move, never a command.
	# Keep source, session and revision validation strict for all old gestures.
	if not _open or _mode!="chest" or session!=int(model.get("session",-1)) or revision!=int(model.get("items_revision",-1)):return
	var row:=_find_item(id)
	if row.is_empty() or row.get("location","")!="bag" or row.get("address",{})!={"kind":"container","id":"player.bag"}:return
	_choose_item(row)

func _refresh_item_actions() -> void:
	var row:=_find_item(str(_item_selection.get("id",""))) if _item_snapshot_current(_item_selection) else {}
	var location:=str(row.get("location",""))
	if not row.is_empty() and row.get("address",{}).get("kind","")=="slot":location="equipment"
	for id in item_actions:
		var action:ItemAction=item_actions[id]
		action.visible=not row.is_empty() and ((id=="equip" and location=="bag") or (id=="store" and location=="bag" and _mode=="chest") or (id=="take" and location=="box") or (id=="unequip" and location=="equipment"))
		action.disabled=not _items_enabled()
		if not action.visible or action.disabled:action.disarm()
	item_action_row.visible=not row.is_empty()
	if row.is_empty():
		detail_label.text="用途 · "+str(model.get("detail","点选物品查看用途；选择钓竿后在此操作。"))
	else:
		var place:="当前工具" if location=="equipment" else "随身" if location=="bag" else "储箱"
		detail_label.text=str(row.get("title",""))+" · "+place+"\n"+str(row.get("hint",""))
	if is_instance_valid(equipment_card):equipment_card.refresh_visual()
	for card in item_cards.values():card.refresh_visual()
	_refresh_resource_actions()

func _disarm_resources() -> void:
	for action in resource_actions.values():action.disarm()

func _resource_snapshot(value: bool) -> Dictionary:
	var row:Dictionary=model.get("bait_action",{})
	return {"resource":str(row.get("resource","")),"source":str(row.get("source","")),"selection":_selected_key,"selection_revision":_resource_selection_revision,"mode":_mode,"epoch":_epoch,"generation":int(model.get("generation",-1)),"session":int(model.get("session",model.get("generation",-1))),"pending":bool(row.get("pending",false)),"count":int(row.get("count",0)),"value":value}

func _field_stew_snapshot() -> Dictionary:
	var row:Dictionary=model.get("field_stew_action",{})
	return {"resource":"stew_servings","source":"player","selection":_selected_key,"selection_revision":_resource_selection_revision,"mode":_mode,"epoch":_epoch,"generation":int(model.get("generation",-1)),"session":int(model.get("session",model.get("generation",-1))),"count":int(row.get("count",0)),"cold":int(row.get("cold",0))}

func _resource_snapshot_current(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or not _open or _mode!="bag" or not _window_focused or not is_inside_tree() or get_tree().paused:return false
	if snapshot.get("resource","")=="stew_servings":
		return _selected_key=="player:stew_servings" and _item_selection.is_empty() and bool(model.get("field_stew_action",{}).get("can_drink",false)) and snapshot==_field_stew_snapshot()
	if _selected_key!="player:shellfish" or not _item_selection.is_empty():return false
	var row:Dictionary=model.get("bait_action",{})
	var value:bool=bool(snapshot.get("value",false))
	if not bool(row.get("can_arm" if value else "can_cancel",false)):return false
	return snapshot==_resource_snapshot(value)

func _refresh_resource_actions() -> void:
	if not is_instance_valid(resource_action_row):return
	var resource_details:bool=_open and _mode=="bag" and _item_selection.is_empty()
	var show_bait:=resource_details and _selected_key=="player:shellfish"
	var show_stew:=resource_details and _selected_key=="player:stew_servings"
	resource_action_row.visible=show_bait or show_stew
	var bait_row:Dictionary=model.get("bait_action",{})
	var stew_row:Dictionary=model.get("field_stew_action",{})
	for key in resource_actions:
		var action:ResourceAction=resource_actions[key]
		var shown:bool=show_stew if action.field_stew else show_bait
		var enabled:bool=bool(stew_row.get("can_drink",false)) if action.field_stew else bool(bait_row.get("can_arm" if action.value else "can_cancel",false))
		action.visible=shown
		action.disabled=not shown or not _window_focused or (is_inside_tree() and get_tree().paused) or not enabled
		if action.disabled:action.disarm()
		elif not action.button_armed.is_empty():
			var frozen:Dictionary=action.button_armed.duplicate(true);frozen.erase("kind")
			if not _resource_snapshot_current(frozen):action.disarm()
	if show_bait or show_stew:
		var row:=stew_row if show_stew else bait_row
		detail_label.text="用途 · "+str(model.get("detail",""))+"\n"+str(row.get("status",""))


func show_rod_notice(text: String) -> void:
	rod_toast.text=text;rod_toast_time=2.2;rod_toast.modulate.a=1.0;rod_toast.show()

func _process(delta: float) -> void:
	if not is_instance_valid(rod_toast):return
	if rod_toast_time>0.0:
		rod_toast_time=maxf(0.0,rod_toast_time-delta)
		rod_toast.modulate.a=minf(1.0,rod_toast_time/1.0)
		var viewport:=get_viewport().get_visible_rect().size
		rod_toast.position=Vector2((viewport.x-360)/2, panel.position.y+16 if _open else maxf(24,viewport.y-180));rod_toast.size=Vector2(360,30)
		if rod_toast_time==0.0:rod_toast.hide()

func clear_rod_notice() -> void:
	rod_toast_time=0.0
	if is_instance_valid(rod_toast):rod_toast.hide()
