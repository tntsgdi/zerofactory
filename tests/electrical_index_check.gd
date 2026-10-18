extends SceneTree
var fails := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL",message])
	if not ok: fails+=1
# Previous algorithm, retained here as a behavioral oracle for the new index.
func original(w, start: int) -> Dictionary:
	var seen := {start:true}; var stack := [start]
	while not stack.is_empty():
		var id = stack.pop_back()
		for lid in w.lines:
			var l = w.lines[lid]
			if not l.alive or l.kind != "cable": continue
			var other: int = l.b if l.a==id else (l.a if l.b==id else -1)
			if other<0 or seen.has(other): continue
			var q = w.pieces.get(other)
			if q==null or q.gone: continue
			seen[other]=true; stack.append(other)
	return seen
func same(w, s) -> bool:
	for id in w.order:
		var actual := {}; s._flood(id,actual,{})
		var expected := original(w,id)
		if actual.size()!=expected.size(): return false
		for key in expected:
			if not actual.has(key): return false
	return true
func _run() -> void:
	for ship in ["tug","s09","pod","gr7","h22","m14","med47","fr26"]:
		var w := World.new(); root.add_child(w)
		Ship.build(w,Ship.load_data(ship))
		var s := Systems.new(); s.world=w
		check(same(w,s),ship+" intact connectivity matches original")
		var cable
		for id in w.lines:
			if w.lines[id].kind=="cable": cable=w.lines[id]; break
		if cable!=null:
			cable.alive=false
			check(same(w,s),ship+" cut cable is observed without stale reachability")
			cable.alive=true
			var p = w.pieces[cable.a]
			p.gone=true
			check(same(w,s),ship+" removed equipment is excluded")
			p.gone=false
			var revision: int = w.electrical_links_version
			var box := Geom.bbox(p.poly)
			w.commit_cut(p,PackedVector2Array([Vector2(box.position.x-20,box.get_center().y),Vector2(box.end.x+20,box.get_center().y)]))
			check(w.electrical_links_version>revision and same(w,s),ship+" real laser split rebuilds endpoint index")
			var q = w.add_piece("plate",Geom.rect_poly(Rect2(10,10,20,20)))
			w.add_line("INDEX-TEST","cable","fixture",q,Vector2.ZERO,q,Vector2.ONE,PackedVector2Array([Vector2.ZERO,Vector2.ONE]))
			check(same(w,s),ship+" new self-loop cable refreshes the index")
		s.free(); w.queue_free()
		await process_frame
	print("ELECTRICAL_INDEX ","PASS" if fails==0 else "FAIL"," failures=",fails)
	quit(0 if fails==0 else 1)
