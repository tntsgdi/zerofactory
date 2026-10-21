extends RefCounted
# What a container drawn as one really holds. Ship files authored before the fire and
# liquid systems left a hundred-odd of them empty: fire bottles, oxygen cabinets, water
# tanks, mud tanks, accumulators, air receivers, service propellant... Cutting one did
# nothing. When a ship file is loaded (Ship.load_data), any equipment of a kind in TABLE
# that the file gives no contents of its own gets them:
#   gas: a pressure vessel on the piece (volume from its outline: a cylinder seen side
#     on, so its depth is its short side, times how much of the box is cylinder), at
#     the pressure such a vessel is charged to; "sealed": a bottle that leaves the ship
#     charged is still equipment (systems.gd's dest_of), only a cut bursts it;
#   liquid: a fluid volume of the piece, so full of it; benign ones ("hazard" off) still
#     go to the equipment bay with it inside.
# Each gets a port on the piece ("<tag>-V" vent, "<tag>-D" drain) to measure it at,
# vent or draw it with a hose; what it holds is added to the contract's value at about
# its worth.

# gas: its gas, its charging pressure (kPa), the share of the box that is vessel, $ per kPa·m³
# liquid: its look (liquids.gd), how full, the share of the box that is tank, $ per m³,
#   t per m³ (its weight in the piece), benign
const TABLE := {
	# fire bottles: liquid CO₂ over its vapour, 5.7 MPa at 20 °C
	"p_ark_fire_bottle": {"gas": "co2", "kpa": 5700.0, "pack": 0.6, "worth": 0.08},
	# oxygen cylinders racked in a cabinet, 150 bar
	"p_ark_o2cab": {"gas": "o2", "kpa": 15000.0, "pack": 0.25, "worth": 0.3},
	"p_o2cab": {"gas": "o2", "kpa": 15000.0, "pack": 0.25, "worth": 0.3},
	"p_bl_o2_store": {"gas": "o2", "kpa": 15000.0, "pack": 0.5, "worth": 0.3},
	"p_dr_n2": {"gas": "n2", "kpa": 15000.0, "pack": 0.5, "worth": 0.08},
	"p_ark_n2_cart": {"gas": "n2", "kpa": 15000.0, "pack": 0.4, "worth": 0.08},
	"p_dr_air_receiver": {"gas": "air", "kpa": 900.0, "pack": 0.7, "worth": 0.02},
	# hydraulic accumulators: the nitrogen precharge over the oil
	"p_dr_accumulator": {"gas": "n2", "kpa": 7000.0, "pack": 0.35, "worth": 0.08},
	"p_dr_bop_accumulator": {"gas": "n2", "kpa": 7000.0, "pack": 0.35, "worth": 0.08},
	"p_fx_he_buffer": {"gas": "he", "kpa": 1600.0, "pack": 0.7, "worth": 1.2},
	# gas samples drawn off the hydrogen plant
	"p_hg_sample_cyl": {"gas": "h2", "kpa": 2000.0, "pack": 0.2, "worth": 0.5},
	"p_water_tank": {"liquid": "water", "fill": 0.7, "pack": 0.6, "worth": 150.0, "t": 1.0, "benign": true},
	"p_ark_ecc_tank": {"liquid": "water", "fill": 0.9, "pack": 0.6, "worth": 150.0, "t": 1.0, "benign": true},
	"p_bl_water_recycler": {"liquid": "water", "fill": 0.6, "pack": 0.4, "worth": 150.0, "t": 1.0, "benign": true},
	"p_sanitation": {"liquid": "water", "fill": 0.5, "pack": 0.4, "worth": 40.0, "t": 1.0, "benign": true},
	"p_ark_dispenser": {"liquid": "water", "fill": 0.5, "pack": 0.3, "worth": 150.0, "t": 1.0, "benign": true},
	"p_bl_pond": {"liquid": "water", "fill": 0.9, "pack": 0.7, "worth": 150.0, "t": 1.0, "benign": true},
	"p_bl_fish_tank": {"liquid": "water", "fill": 0.9, "pack": 0.7, "worth": 150.0, "t": 1.0, "benign": true},
	"p_bl_fry_tank": {"liquid": "water", "fill": 0.9, "pack": 0.6, "worth": 150.0, "t": 1.0, "benign": true},
	"p_ballast": {"liquid": "water", "fill": 0.6, "pack": 0.7, "worth": 20.0, "t": 1.0, "benign": true},
	"p_waste_tank": {"liquid": "water", "fill": 0.5, "pack": 0.6, "worth": 10.0, "t": 1.0, "benign": true},
	"p_dr_mud_tank": {"liquid": "mud", "fill": 0.6, "pack": 0.7, "worth": 120.0, "t": 1.8, "benign": true},
	"p_foam": {"liquid": "foam", "fill": 0.8, "pack": 0.6, "worth": 900.0, "t": 1.0, "benign": true},
	"p_ark_lube_tank": {"liquid": "oil", "fill": 0.6, "pack": 0.6, "worth": 900.0, "t": 0.87},
	"p_lube_tank": {"liquid": "oil", "fill": 0.6, "pack": 0.6, "worth": 900.0, "t": 0.87},
	# hydrazine-family service propellant (attitude thrusters)
	"p_svc_prop": {"liquid": "mmh", "fill": 0.4, "pack": 0.6, "worth": 4000.0, "t": 0.88},
	"p_ark_fuel_cart": {"liquid": "fuel", "fill": 0.5, "pack": 0.5, "worth": 1500.0, "t": 0.8},
}

# the fluid kind a liquid of this look is recovered and valued as
const KIND := {"mmh": "fuel", "fuel": "fuel", "oil": "oil", "water": "water", "mud": "mud", "foam": "foam"}


static func _poly(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in a:
		out.append(Vector2(float(q[0]), float(q[1])))
	return out


# fill in the ship file d (once)
static func add(d: Dictionary) -> void:
	if d.get("_contents", false):
		return
	d["_contents"] = true
	var gas: Dictionary = d.get("gas", {})
	var vessels: Dictionary = gas.get("vessels", {})
	var fl: Dictionary = d.get("fluids", {})
	var vols: Dictionary = fl.get("volumes", {})
	var held := {}
	for k in vessels:
		held[str(vessels[k].get("piece", ""))] = true
	for k in vols:
		held[str(vols[k].get("piece", ""))] = true
	var ctrl_ids := {}
	for c in d.get("ctrls", []):
		ctrl_ids[str(c.id)] = true
	var rooms: Array = []
	for r in d.get("rooms", []):
		rooms.append([str(r.name), _poly(r.poly)])
	var gas_worth := 0.0
	var fl_worth := {}
	var added := 0
	for pd in d.get("pieces", []):
		if str(pd.get("cls", "")) != "equip":
			continue
		var tag: String = str(pd.get("tag", ""))
		var e = TABLE.get(str(pd.get("name_key", "")))
		if e == null or tag == "" or held.has(tag):
			continue
		var poly := _poly(pd.poly)
		var bb := Geom.bbox(poly)
		var depth: float = minf(bb.size.x, bb.size.y)
		var vol: float = absf(Geom.area(poly)) * depth * float(e.pack)
		if vol <= 0.001:
			continue
		var at := Geom.centroid(poly)
		# a port inside a room is reached from inside it (and only seen once it is opened up)
		var room := ""
		for r in rooms:
			if Geometry2D.is_point_in_polygon(at, r[1]):
				room = r[0]
				break
		if e.has("gas"):
			var vid := tag + "~G"
			var pid := tag + "-V"
			if ctrl_ids.has(pid):
				continue
			vessels[vid] = {"V": snappedf(vol, 0.001), "kpa": float(e.kpa), "piece": tag, "burst": 200.0, "gas": e.gas, "sealed": true, "contents": true}
			var cg := {"id": pid, "kind": "port", "piece": pd.key, "at": [at.x, at.y], "medium": "gas", "target": vid}
			if room != "":
				cg["hidden_room"] = room
			d.ctrls.append(cg)
			gas_worth += float(e.kpa) * vol * float(e.worth)
		else:
			var fid := tag + "~L"
			var did := tag + "-D"
			if ctrl_ids.has(did):
				continue
			var kind: String = KIND.get(str(e.liquid), "water")
			var amt: float = snappedf(vol * float(e.fill), 0.001)
			var v := {"fluid": kind, "look": e.liquid, "amount": amt, "full": snappedf(vol, 0.001), "piece": tag, "port": did,
				"content": float(e.t), "leak": 0.05, "pump": [0.25, 0.01], "contents": true}
			if e.get("benign", false):
				v["hazard"] = 1.0e9
			vols[fid] = v
			var cl := {"id": did, "kind": "port", "piece": pd.key, "at": [at.x, at.y], "medium": "fluid", "target": fid}
			if room != "":
				cl["hidden_room"] = room
			d.ctrls.append(cl)
			fl_worth[kind] = float(fl_worth.get(kind, 0.0)) + amt * float(e.worth)
		added += 1
	if added == 0:
		return
	gas["vessels"] = vessels
	gas["value"] = float(gas.get("value", 0.0)) + roundf(gas_worth)
	d["gas"] = gas
	fl["volumes"] = vols
	var val: Dictionary = fl.get("value", {})
	for k in fl_worth:
		val[k] = float(val.get(k, 0.0)) + roundf(fl_worth[k])
	fl["value"] = val
	d["fluids"] = fl
	var tot: Dictionary = d.get("value", {})
	if tot.has("total"):
		tot.total = float(tot.total) + roundf(gas_worth)
		for k in fl_worth:
			tot.total = float(tot.total) + roundf(fl_worth[k])
	d["_contents_n"] = added
