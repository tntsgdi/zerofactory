class_name Model
# Plain data for the ship: pieces (polygons with mass and value), joints that
# hold them together, cables and pipes that run between them, and the controls
# and ports the player can touch. Every position lives in its group's frame:
# world space while attached to the dock, body-local once it floats free.

const ANCHOR := -1


class Piece:
	var id := 0
	var kind := "hull"        # hull hatch bulkhead door deck keel rib rail beam strut plate fixture equip lamp
	var tag := ""             # "NAV-01" etc. for named equipment
	var name_key := ""        # Txt key
	var label := ""           # short text printed on its art ("O₂", "PRECISION")
	var poly := PackedVector2Array()
	var body: Node = null     # FreeBody or null (attached)
	var mass := 0.0           # tonnes
	var density := 1.0        # t per m² of section, for structure
	var cls := "metal"        # metal | equip
	var value := 0.0          # intact value (equip)
	var cond := 1.0           # 0..1 condition of equipment
	var intact := true        # never touched by the laser
	var art := ""             # procedural art id ("" = plain plate)
	var art_xf := Transform2D()   # art space -> group frame
	var art_size := Vector2.ZERO
	var fragile := 0.3
	var contam := false
	var cut_speed := 260.0    # px/s through this material
	var room := ""            # room it sits in ("" = hull / outside)
	var barrier := false      # blocks gas (hull, bulkheads, decks, closed doors)
	var door := false
	var door_open := false
	var open_t := 0.0
	var open_dir := Vector2.ZERO
	var heat: Array = []      # [a, b, t] kerf edges, group frame
	var hazard := ""          # gas_tank fuel_tank cap battery gen
	var temp := 20.0
	var gone := false
	var mandatory := false
	var scope := true         # inside what the contract pays for
	var dest := "metal"       # where it pays most: metal | equip | hazard
	var hidden_by := -1       # a cover piece that has to come off first
	var seen := false
	var tri := PackedInt32Array()   # cached triangulation of poly (drawing)
	var tri_sig := 0

	func world_xf() -> Transform2D:
		return body.global_transform if body != null else Transform2D.IDENTITY

	func world_poly() -> PackedVector2Array:
		return world_xf() * poly

	func center_world() -> Vector2:
		return world_xf() * Geom.centroid(poly)


class Joint:
	var id := 0
	var a := 0
	var b := -1
	var type := "bolt"        # weld bolt lock clamp
	var pos := Vector2.ZERO   # group frame of piece a
	var alive := true
	var strain := 0.0


class Line:
	var id := ""
	var kind := "cable"       # cable pipe
	var net := ""             # electric / coolant / fuel / gas / none
	var a := 0                # piece at end A
	var b := 0
	var pa := Vector2.ZERO    # end A in piece a's group frame
	var pb := Vector2.ZERO
	var path := PackedVector2Array()   # world route while both ends are attached
	var alive := true
	var cut_at := Vector2.ZERO
	var strain := 0.0
	var label := ""


class Ctrl:
	var id := ""
	var kind := "port"        # port test valve switch stop socket discharge door hatch jam
	var piece := 0
	var pos := Vector2.ZERO   # group frame of the piece
	var state := false
	var medium := ""          # gas fuel coolant volt
	var target := ""          # volume / node / door piece the control acts on
	var label := ""
	var busy := 0.0
	var hidden_room := ""     # only reachable once this room is open
