class_name Art
# Line art for named equipment, drawn inside its own rectangle (0,0)-(w,h).
# White ink only; the heat orange is never used here. The fleet's shared machines
# (pumps, switchboards, batteries...) live in art_equip.gd.

const EQ = preload("res://scripts/art_equip.gd")
const SH = preload("res://scripts/art_ships.gd")

static func L(ci: CanvasItem, a: Vector2, b: Vector2, al: float = 0.5, wd: float = 1.0) -> void:
	ci.draw_line(a, b, Pal.ink(al), wd, true)


static func box(ci: CanvasItem, r: Rect2, al: float = 0.5, wd: float = 1.0) -> void:
	ci.draw_rect(r, Pal.ink(al), false, wd)


static func ring(ci: CanvasItem, c: Vector2, r: float, al: float = 0.5, wd: float = 1.0) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 28, Pal.ink(al), wd, true)


static func draw(ci: CanvasItem, art: String, s: Vector2, p, font: Font) -> void:
	var w := s.x
	var h := s.y
	if EQ.ext == null:
		EQ.ext = SH
	if EQ.draw(ci, art, w, h, p, font):
		return
	match art:
		"window":
			pass
		"seat":
			# the piece itself is the couch's outline; here only its seams, the harness and the side stick
			L(ci, Vector2(w * 0.83, h * 0.17), Vector2(w * 0.97, h * 0.2), 0.4)
			L(ci, Vector2(w * 0.06, h * 0.69), Vector2(w * 0.62, h * 0.68), 0.3)
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.88, h * 0.24), Vector2(w * 0.42, h * 0.5), Vector2(w * 0.2, h * 0.64)]), Pal.ink(0.35), 1.0, true)
			L(ci, Vector2(w * 0.12, h * 0.64), Vector2(w * 0.1, h * 0.5), 0.5, 1.2)
			ci.draw_circle(Vector2(w * 0.1, h * 0.49), 1.6, Pal.ink(0.5))
		"cover":
			L(ci, Vector2(w * 0.2, h * 0.5), Vector2(w * 0.8, h * 0.5), 0.3)
			ci.draw_string(font, Vector2(w * 0.12, h * 0.3), "SERVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.ink(0.35))
		"armor":
			# a ring quad (outer a b, inner c d): a seam line inset from the outside, rivets down the middle
			if p != null and p.poly.size() == 4:
				var o: Vector2 = Geom.bbox(p.poly).position
				var q: PackedVector2Array = p.poly
				L(ci, q[0].lerp(q[3], 0.3) - o, q[1].lerp(q[2], 0.3) - o, 0.3)
				var m0: Vector2 = (q[0] + q[3]) * 0.5 - o
				var m1: Vector2 = (q[1] + q[2]) * 0.5 - o
				var n := clampi(int(m0.distance_to(m1) / 34.0), 1, 24)
				for i in n:
					ci.draw_circle(m0.lerp(m1, (i + 0.5) / n), 1.4, Pal.ink(0.45))
			else:
				var hz := w >= h
				for i in 6:
					var t := (i + 0.5) / 6.0
					ci.draw_circle(Vector2(w * t, h * 0.5) if hz else Vector2(w * 0.5, h * t), 1.4, Pal.ink(0.45))
		"insul":
			# an insulated wall: its foam core between two skins, quilted
			var hz := w >= h
			if hz:
				L(ci, Vector2(1, h * 0.25), Vector2(w - 1, h * 0.25), 0.2)
				L(ci, Vector2(1, h * 0.75), Vector2(w - 1, h * 0.75), 0.2)
				for i in int(w / 14.0):
					L(ci, Vector2(7 + i * 14, h * 0.25), Vector2(14 + i * 14, h * 0.75), 0.15)
			else:
				L(ci, Vector2(w * 0.25, 1), Vector2(w * 0.25, h - 1), 0.2)
				L(ci, Vector2(w * 0.75, 1), Vector2(w * 0.75, h - 1), 0.2)
				for i in int(h / 14.0):
					L(ci, Vector2(w * 0.25, 7 + i * 14), Vector2(w * 0.75, 14 + i * 14), 0.15)
		"vault":
			# a radial vault door seen edge-on: its locking bolts down both faces, the hinge
			for i in 5:
				var y := h * (0.1 + i * 0.2)
				L(ci, Vector2(0, y), Vector2(w * 0.3, y), 0.5, 2.0)
				L(ci, Vector2(w * 0.7, y), Vector2(w, y), 0.5, 2.0)
			L(ci, Vector2(w * 0.5, h * 0.04), Vector2(w * 0.5, h * 0.96), 0.3)
		"glass":
			# a pane of precision glazing: two glints across it, its frame
			L(ci, Vector2(w * 0.12, h * 0.85), Vector2(w * 0.3, h * 0.15), 0.35)
			L(ci, Vector2(w * 0.2, h * 0.85), Vector2(w * 0.38, h * 0.15), 0.2)
			if p != null and p.cond < 0.5:
				for i in 4:
					L(ci, Vector2(w * (0.5 + i * 0.1), h * 0.1), Vector2(w * (0.45 + i * 0.12), h * 0.9), 0.5)
		"tf_coil":
			# a superconducting coil cut across: the steel case, its ground insulation, the
			# winding pack of cable-in-conduit turns (each jacket with its helium channel),
			# the radial plates every few turns, the helium inlets at both ends
			var cs: float = clampf(minf(w, h) * 0.13, 3.0, 9.0)
			box(ci, Rect2(cs, cs, w - 2.0 * cs, h - 2.0 * cs), 0.55)
			var wp := Rect2(cs * 1.6, cs * 1.6, w - 3.2 * cs, h - 3.2 * cs)
			box(ci, wp, 0.2)
			var cell := 7.0
			var nx := maxi(1, int(wp.size.x / cell))
			var ny := maxi(1, int(wp.size.y / cell))
			var cw: float = wp.size.x / nx
			var chh: float = wp.size.y / ny
			for ix in nx:
				for iy in ny:
					var c0: Vector2 = wp.position + Vector2(ix * cw, iy * chh)
					box(ci, Rect2(c0 + Vector2(1, 1), Vector2(cw - 2, chh - 2)), 0.18)
					ci.draw_rect(Rect2(c0 + Vector2(cw * 0.5 - 0.7, chh * 0.5 - 0.7), Vector2(1.4, 1.4)), Pal.ink(0.35))
			var vert: bool = h >= w
			for k in range(2, (ny if vert else nx), 4):
				if vert:
					L(ci, Vector2(wp.position.x, wp.position.y + k * chh), Vector2(wp.end.x, wp.position.y + k * chh), 0.35)
				else:
					L(ci, Vector2(wp.position.x + k * cw, wp.position.y), Vector2(wp.position.x + k * cw, wp.end.y), 0.35)
			for e in 2:
				var pt := Vector2(w * 0.5, cs * 0.8 if e == 0 else h - cs * 0.8) if vert else Vector2(cs * 0.8 if e == 0 else w - cs * 0.8, h * 0.5)
				ring(ci, pt, 2.2, 0.6)
			if p != null and p.cond < 0.5:
				# quenched: the winding pack burnt through in a band
				L(ci, Vector2(w * 0.2, h * 0.35), Vector2(w * 0.8, h * 0.45), 0.6, 2.0)
				L(ci, Vector2(w * 0.3, h * 0.5), Vector2(w * 0.7, h * 0.58), 0.5, 1.5)
		"cs_stack":
			# a central solenoid module: pancake windings stacked between the tie plates,
			# the bore down its middle, the pre-compression flanges top and bottom
			var tp: float = w * 0.07
			for x0 in [0.0, w - tp]:
				box(ci, Rect2(x0, 0, tp, h), 0.5)
				for i in int(h / 24.0):
					ring(ci, Vector2(x0 + tp * 0.5, 12.0 + i * 24.0), tp * 0.25, 0.4)
			box(ci, Rect2(tp, 0, w - 2.0 * tp, h * 0.035), 0.6)
			box(ci, Rect2(tp, h * 0.965, w - 2.0 * tp, h * 0.035), 0.6)
			var bore := Rect2(w * 0.43, h * 0.035, w * 0.14, h * 0.93)
			box(ci, bore, 0.35)
			for i in int(h / 10.0):
				var y: float = h * 0.04 + i * 10.0
				if y > h * 0.95:
					break
				L(ci, Vector2(tp, y), Vector2(bore.position.x, y), 0.28)
				L(ci, Vector2(bore.end.x, y), Vector2(w - tp, y), 0.28)
				for j in int((bore.position.x - tp) / 6.0):
					L(ci, Vector2(tp + 3.0 + j * 6.0, y + 2.0), Vector2(tp + 3.0 + j * 6.0, y + 8.0), 0.14)
					L(ci, Vector2(bore.end.x + 3.0 + j * 6.0, y + 2.0), Vector2(bore.end.x + 3.0 + j * 6.0, y + 8.0), 0.14)
			for i in int(h / 14.0):
				L(ci, Vector2(w * 0.5, i * 14.0 + 2.0), Vector2(w * 0.5, i * 14.0 + 8.0), 0.3)
		"fw_d", "fw_u", "fw_l", "fw_r":
			# a blanket module: beryllium first-wall tiles on the face the plasma sees, the
			# steel shield block behind with its coolant channels, the attachment key
			var face: String = art.substr(3)
			var vert: bool = face == "l" or face == "r"
			var ln: float = h if vert else w
			var th: float = w if vert else h
			var tile_t: float = th * 0.22
			var n := maxi(2, int(ln / 7.0))
			for i in n:
				var a0: float = i * ln / n + 0.6
				var a1: float = (i + 1) * ln / n - 0.6
				var r: Rect2
				match face:
					"d": r = Rect2(a0, h - tile_t, a1 - a0, tile_t)
					"u": r = Rect2(a0, 0, a1 - a0, tile_t)
					"l": r = Rect2(0, a0, tile_t, a1 - a0)
					_: r = Rect2(w - tile_t, a0, tile_t, a1 - a0)
				box(ci, r, 0.5)
			var mid: float = th * 0.55 if face in ["u", "l"] else th * 0.45
			for i in maxi(2, int(ln / 12.0)):
				var a: float = (i + 0.5) * ln / maxi(2, int(ln / 12.0))
				ring(ci, Vector2(mid, a) if vert else Vector2(a, mid), th * 0.09, 0.35)
			var key_d: float = th * 0.9 if face in ["d", "r"] else th * 0.1
			if vert:
				box(ci, Rect2(key_d - th * 0.08, ln * 0.42, th * 0.16, ln * 0.16), 0.55)
			else:
				box(ci, Rect2(ln * 0.42, key_d - th * 0.08, ln * 0.16, th * 0.16), 0.55)
		"divertor":
			# a divertor cassette: the steel body, the inner and outer vertical targets of
			# tungsten monoblocks rising at either end, the dome between, its coolant pipes
			var body := Rect2(0, h * 0.58, w, h * 0.42)
			box(ci, body, 0.55)
			for i in 6:
				ring(ci, Vector2(w * (0.12 + i * 0.152), h * 0.8), h * 0.06, 0.3)
			for side in [0, 1]:
				var x0: float = w * 0.03 if side == 0 else w * 0.97
				var x1: float = w * 0.2 if side == 0 else w * 0.8
				var a := Vector2(x0, h * 0.58)
				var b := Vector2(x1, h * 0.04)
				L(ci, a, b, 0.6, 2.0)
				for k in 8:
					var q: Vector2 = a.lerp(b, (k + 0.5) / 8.0)
					var nrm: Vector2 = (b - a).normalized().orthogonal() * (4.0 if side == 0 else -4.0)
					L(ci, q, q + nrm, 0.4)
			ci.draw_arc(Vector2(w * 0.5, h * 0.58), w * 0.14, PI, TAU, 16, Pal.ink(0.55), 1.4, true)
			L(ci, Vector2(w * 0.32, h * 0.58), Vector2(w * 0.32, h * 0.66), 0.3)
			L(ci, Vector2(w * 0.68, h * 0.58), Vector2(w * 0.68, h * 0.66), 0.3)
		"vv_wall":
			# a vacuum vessel wall section: inner and outer shells with the ribs between
			# (the gap is where the shielding water runs)
			var vert: bool = h >= w
			var ln: float = h if vert else w
			var th: float = w if vert else h
			for f in [0.15, 0.85]:
				if vert:
					L(ci, Vector2(th * f, 0), Vector2(th * f, ln), 0.4)
				else:
					L(ci, Vector2(0, th * f), Vector2(ln, th * f), 0.4)
			for i in int(ln / 14.0):
				var a: float = 7.0 + i * 14.0
				if vert:
					L(ci, Vector2(th * 0.15, a), Vector2(th * 0.85, a), 0.22)
				else:
					L(ci, Vector2(a, th * 0.15), Vector2(a, th * 0.85), 0.22)
		"grav_support":
			# a coil support: a stack of thin flexible plates between two end blocks, so the
			# coil can shrink as it cools without loading the floor
			var vert: bool = h >= w
			var ln: float = h if vert else w
			var th: float = w if vert else h
			if vert:
				box(ci, Rect2(0, 0, w, ln * 0.15), 0.5)
				box(ci, Rect2(0, ln * 0.85, w, ln * 0.15), 0.5)
			else:
				box(ci, Rect2(0, 0, ln * 0.15, h), 0.5)
				box(ci, Rect2(ln * 0.85, 0, ln * 0.15, h), 0.5)
			for i in maxi(2, int(th / 3.5)):
				var a: float = (i + 0.5) * th / maxi(2, int(th / 3.5))
				if vert:
					L(ci, Vector2(a, ln * 0.15), Vector2(a, ln * 0.85), 0.3)
				else:
					L(ci, Vector2(ln * 0.15, a), Vector2(ln * 0.85, a), 0.3)
		"gyrotron":
			# a gyrotron stood on end: the electron gun at the foot, the beam tunnel and
			# cavity up the middle inside its superconducting magnet, the output window on
			# the side, the finned collector on top
			var cx: float = w * 0.5
			ci.draw_polyline(PackedVector2Array([Vector2(cx - w * 0.2, h * 0.97), Vector2(cx, h * 0.8), Vector2(cx + w * 0.2, h * 0.97)]), Pal.ink(0.55), 1.2, true)
			box(ci, Rect2(w * 0.12, h * 0.38, w * 0.76, h * 0.36), 0.55)
			box(ci, Rect2(w * 0.2, h * 0.42, w * 0.6, h * 0.28), 0.25)
			L(ci, Vector2(cx - 2, h * 0.8), Vector2(cx - 2, h * 0.3), 0.45)
			L(ci, Vector2(cx + 2, h * 0.8), Vector2(cx + 2, h * 0.3), 0.45)
			box(ci, Rect2(cx - 4, h * 0.52, 8, h * 0.06), 0.6)
			var wnd := Vector2(w * 0.86, h * 0.28)
			ci.draw_polyline(PackedVector2Array([wnd + Vector2(-4, 0), wnd + Vector2(0, -4), wnd + Vector2(4, 0), wnd + Vector2(0, 4), wnd + Vector2(-4, 0)]), Pal.ink(0.6), 1.0, true)
			L(ci, Vector2(cx, h * 0.28), wnd, 0.3)
			box(ci, Rect2(w * 0.22, h * 0.03, w * 0.56, h * 0.24), 0.55)
			for i in 6:
				var y: float = h * (0.06 + i * 0.035)
				L(ci, Vector2(w * 0.14, y), Vector2(w * 0.22, y), 0.3)
				L(ci, Vector2(w * 0.78, y), Vector2(w * 0.86, y), 0.3)
		"coldbox":
			# a cryoplant cold box: the vacuum vessel, three brazed plate-fin heat exchangers
			# up the middle, the turbo-expanders below them, the transfer lines out the top
			box(ci, Rect2(w * 0.04, h * 0.04, w * 0.92, h * 0.92), 0.4)
			for i in 3:
				var r := Rect2(w * (0.12 + i * 0.27), h * 0.1, w * 0.2, h * 0.5)
				box(ci, r, 0.5)
				var zz := PackedVector2Array()
				for k in 12:
					zz.append(Vector2(r.position.x + (2.0 if k % 2 == 0 else r.size.x - 2.0), r.position.y + 3.0 + k * (r.size.y - 6.0) / 11.0))
				ci.draw_polyline(zz, Pal.ink(0.22), 1.0, true)
				var tc := Vector2(r.get_center().x, h * 0.76)
				ring(ci, tc, w * 0.07, 0.55)
				L(ci, tc + Vector2(-w * 0.05, 0), tc + Vector2(w * 0.05, 0), 0.4)
				L(ci, tc + Vector2(0, -w * 0.05), tc + Vector2(0, w * 0.05), 0.4)
				L(ci, Vector2(tc.x, r.end.y), tc + Vector2(0, -w * 0.07), 0.3)
			for x in [0.3, 0.5, 0.7]:
				L(ci, Vector2(w * x, 0), Vector2(w * x, h * 0.1), 0.4)
		"turbo":
			# a turbomolecular pump: the inlet flange, the stack of rotor and stator blade
			# rows, the motor and bearings below, the backing port on the side
			box(ci, Rect2(0, 0, w, h * 0.08), 0.6)
			box(ci, Rect2(w * 0.12, h * 0.08, w * 0.76, h * 0.62), 0.5)
			for i in 9:
				var y: float = h * (0.12 + i * 0.065)
				var sg: float = 3.0 if i % 2 == 0 else -3.0
				for k in int(w * 0.7 / 6.0):
					var x: float = w * 0.15 + k * 6.0
					L(ci, Vector2(x, y), Vector2(x + sg, y + 3.0), 0.3)
			L(ci, Vector2(w * 0.5, h * 0.1), Vector2(w * 0.5, h * 0.9), 0.35)
			box(ci, Rect2(w * 0.25, h * 0.7, w * 0.5, h * 0.26), 0.5)
			box(ci, Rect2(w * 0.88, h * 0.55, w * 0.12, h * 0.1), 0.5)
		"ech":
			# an electron-cyclotron launcher: the bundle of corrugated waveguides coming in,
			# the fixed focusing mirror, the steering mirror that aims the beam, the port flange
			for i in 4:
				var y: float = h * (0.2 + i * 0.18)
				L(ci, Vector2(0, y), Vector2(w * 0.55, y), 0.35)
				for k in int(w * 0.5 / 5.0):
					L(ci, Vector2(k * 5.0 + 2.0, y - 1.5), Vector2(k * 5.0 + 2.0, y + 1.5), 0.15)
			ci.draw_arc(Vector2(w * 0.62, h * 0.5), h * 0.42, -1.1, 1.1, 12, Pal.ink(0.55), 1.4, true)
			L(ci, Vector2(w * 0.78, h * 0.15), Vector2(w * 0.9, h * 0.85), 0.6, 1.6)
			box(ci, Rect2(w * 0.94, 0, w * 0.06, h), 0.5)
		"pellet":
			# a pellet injector: the screw extruder freezing deuterium ice under its cold
			# head, the cutter, the gas-gun barrel out to the side
			ring(ci, Vector2(w * 0.35, h * 0.12), w * 0.14, 0.55)
			box(ci, Rect2(w * 0.22, h * 0.22, w * 0.26, h * 0.6), 0.5)
			var zz := PackedVector2Array()
			for k in 10:
				zz.append(Vector2(w * (0.25 if k % 2 == 0 else 0.45), h * (0.25 + k * 0.055)))
			ci.draw_polyline(zz, Pal.ink(0.3), 1.0, true)
			box(ci, Rect2(w * 0.48, h * 0.7, w * 0.12, h * 0.1), 0.5)
			L(ci, Vector2(w * 0.6, h * 0.73), Vector2(w, h * 0.73), 0.55, 1.6)
			L(ci, Vector2(w * 0.6, h * 0.77), Vector2(w, h * 0.77), 0.55, 1.6)
			box(ci, Rect2(w * 0.05, h * 0.82, w * 0.4, h * 0.14), 0.4)
		"dump_res":
			# the dump resistor: banks of stainless ribbon folded back and forth between the
			# busbars, the air gaps that cool it
			L(ci, Vector2(w * 0.05, h * 0.08), Vector2(w * 0.95, h * 0.08), 0.6, 2.0)
			L(ci, Vector2(w * 0.05, h * 0.92), Vector2(w * 0.95, h * 0.92), 0.6, 2.0)
			for c in 4:
				var x0: float = w * (0.1 + c * 0.22)
				var zz := PackedVector2Array()
				for k in 14:
					zz.append(Vector2(x0 + (0.0 if k % 2 == 0 else w * 0.14), h * (0.1 + k * 0.06)))
				ci.draw_polyline(zz, Pal.ink(0.35), 1.0, true)
		"port_plug":
			# a diagnostic port plug: the shielding block that fills the port, the mirror
			# labyrinth the light threads through, the closure plate on the outer end
			var vert: bool = h >= w
			box(ci, Rect2(0, 0, w, h), 0.4)
			if vert:
				box(ci, Rect2(0, 0, w * 0.18, h), 0.6)
				var pts := PackedVector2Array([Vector2(w, h * 0.3), Vector2(w * 0.6, h * 0.3), Vector2(w * 0.6, h * 0.55), Vector2(w * 0.3, h * 0.55), Vector2(w * 0.3, h * 0.75), Vector2(w * 0.18, h * 0.75)])
				ci.draw_polyline(pts, Pal.ink(0.4), 1.0, true)
				for q in [Vector2(w * 0.6, h * 0.3), Vector2(w * 0.6, h * 0.55), Vector2(w * 0.3, h * 0.55), Vector2(w * 0.3, h * 0.75)]:
					L(ci, q + Vector2(-3, -3), q + Vector2(3, 3), 0.6, 1.4)
				for i in int(h / 9.0):
					L(ci, Vector2(w * 0.7, i * 9.0 + 3.0), Vector2(w * 0.95, i * 9.0 + 6.0), 0.12)
		"nbi":
			# a neutral beam injector: the ion source and its accelerator grids, the gas
			# neutraliser, the bending magnet that sweeps out what stayed charged into the
			# residual ion dump, the calorimeter, the cryopumps on top, the duct to the torus
			var src := Rect2(w * 0.01, h * 0.15, w * 0.12, h * 0.7)
			box(ci, src, 0.6)
			for i in 4:
				L(ci, Vector2(src.end.x + 2.0 + i * 3.0, h * 0.2), Vector2(src.end.x + 2.0 + i * 3.0, h * 0.8), 0.45)
			box(ci, Rect2(w * 0.17, h * 0.32, w * 0.28, h * 0.36), 0.45)
			box(ci, Rect2(w * 0.47, h * 0.22, w * 0.08, h * 0.56), 0.55)
			for i in 6:
				L(ci, Vector2(w * 0.57, h * (0.25 + i * 0.09)), Vector2(w * 0.66, h * (0.25 + i * 0.09)), 0.35)
			box(ci, Rect2(w * 0.68, h * 0.3, w * 0.1, h * 0.4), 0.5)
			for i in 5:
				L(ci, Vector2(w * 0.68, h * (0.3 + i * 0.1)), Vector2(w * 0.78, h * (0.4 + i * 0.1)), 0.2)
			L(ci, Vector2(w * 0.8, h * 0.4), Vector2(w, h * 0.42), 0.5)
			L(ci, Vector2(w * 0.8, h * 0.6), Vector2(w, h * 0.58), 0.5)
			for i in 3:
				ring(ci, Vector2(w * (0.22 + i * 0.1), h * 0.14), h * 0.1, 0.45)
			L(ci, Vector2(src.end.x, h * 0.5), Vector2(w, h * 0.5), 0.12)
		"mirror":
			# a mirror seen edge-on: the coated face down its left side, the ribbed
			# lightweighted blank behind it, its edges chamfered; dusty, specks on the face
			L(ci, Vector2(1.0, 1.0), Vector2(1.0, h - 1.0), 0.85, 2.0)
			L(ci, Vector2(w * 0.3, 0.0), Vector2(w * 0.3, h), 0.25)
			for i in int(maxf(2.0, h / 7.0)):
				var y := h * (i + 0.5) / maxf(2.0, h / 7.0)
				L(ci, Vector2(w * 0.3, y), Vector2(w * 0.95, y - h * 0.08), 0.2)
				L(ci, Vector2(w * 0.3, y), Vector2(w * 0.95, y + h * 0.08), 0.2)
			L(ci, Vector2(w * 0.08, h * 0.15), Vector2(w * 0.08, h * 0.4), 0.4)
			if p != null and p.cond < 0.9:
				for i in int((1.0 - p.cond) * 12.0):
					var y := h * fposmod(i * 0.618, 1.0)
					L(ci, Vector2(2.0, y), Vector2(4.0, y + 1.0), 0.6, 1.5)
			if p != null and p.cond < 0.5:
				L(ci, Vector2(0.0, h * 0.2), Vector2(w * 0.7, h * 0.55), 0.6)
				L(ci, Vector2(w * 0.7, h * 0.55), Vector2(w * 0.4, h * 0.9), 0.5)
		"plants":
			# a culture rack: its trays, the shoots in them
			for i in 3:
				L(ci, Vector2(w * 0.02, h * (0.3 + i * 0.3)), Vector2(w * 0.98, h * (0.3 + i * 0.3)), 0.35)
			for i in int(maxf(4.0, w / 9.0)):
				var x := w * (0.04 + i * 9.0 / maxf(w, 1.0))
				if x > w - 3.0:
					break
				for k in 3:
					var y0 := h * (0.3 + k * 0.3)
					L(ci, Vector2(x, y0), Vector2(x - 2.0, y0 - h * 0.18), 0.4)
					L(ci, Vector2(x, y0), Vector2(x + 2.0, y0 - h * 0.15), 0.3)
		"barrel":
			L(ci, Vector2(2, h * 0.5), Vector2(w - 2, h * 0.5), 0.3)
			for x in [0.04, 0.07, 0.6, 0.94]:
				L(ci, Vector2(w * x, 1), Vector2(w * x, h - 1), 0.45)
		"turret":
			L(ci, Vector2(w * 0.3, h * 0.35), Vector2(w * 0.8, h * 0.35), 0.35)
			box(ci, Rect2(w * 0.55, h * 0.12, w * 0.14, h * 0.16), 0.45)
			for i in 3:
				L(ci, Vector2(w * (0.2 + i * 0.05), h * 0.6), Vector2(w * (0.2 + i * 0.05), h * 0.9), 0.3)
			ci.draw_string(font, Vector2(w * 0.4, h * 0.82), "76", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.ink(0.4))
		"gun_mount":
			ci.draw_arc(Vector2(w * 0.5, 0), w * 0.4, 0.0, PI, 20, Pal.ink(0.5), 1.0, true)
			for i in 5:
				L(ci, Vector2(w * (0.18 + i * 0.16), h * 0.5), Vector2(w * (0.18 + i * 0.16), h * 0.95), 0.25)
		"missile", "shell":
			# along its long side: the nose, the body's bands, the fins (a round: its driving band)
			var hz := w > h
			var ln := w if hz else h
			var br := h if hz else w
			var at := func(u: float, v: float) -> Vector2: return Vector2(u, v) if hz else Vector2(v, u)
			ci.draw_polyline(PackedVector2Array([at.call(ln * 0.12, 1.0), at.call(1.0, br * 0.5), at.call(ln * 0.12, br - 1.0)]), Pal.ink(0.5), 1.0, true)
			if art == "missile":
				for u in [0.3, 0.62]:
					L(ci, at.call(ln * u, 1.0), at.call(ln * u, br - 1.0), 0.35)
				L(ci, at.call(ln * 0.84, 0.0), at.call(ln, 0.0), 0.5)
				L(ci, at.call(ln * 0.84, br), at.call(ln, br), 0.5)
			else:
				L(ci, at.call(ln * 0.7, 1.0), at.call(ln * 0.7, br - 1.0), 0.5)
				L(ci, at.call(ln * 0.76, 1.0), at.call(ln * 0.76, br - 1.0), 0.5)
			if p != null and p.has_meta("wet"):
				ci.draw_string(font, at.call(ln * 0.36, br * 0.5) + Vector2(-8, 3), "WET", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.ink(0.55))
		"decoy":
			for i in 3:
				var x := w * (0.2 + i * 0.3)
				L(ci, Vector2(x, h * 0.95), Vector2(x + w * 0.12, h * 0.1), 0.5, 2.0)
		"launcher":
			L(ci, Vector2(2, h * 0.5), Vector2(w - 2, h * 0.5), 0.35)
			ci.draw_string(font, Vector2(w * 0.4, h * 0.9), "BOX L", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.ink(0.4))
		"ciws":
			ci.draw_arc(Vector2(w * 0.5, h * 0.62), w * 0.3, PI, TAU, 18, Pal.ink(0.5), 1.0, true)
			for i in 3:
				L(ci, Vector2(w * 0.06, h * (0.52 + i * 0.1)), Vector2(w * 0.3, h * (0.52 + i * 0.1)), 0.4)
		"reactor":
			var c := Vector2(w * 0.5, h * 0.5)
			for k in 3:
				ring(ci, c, minf(w, h) * (0.18 + k * 0.1), 0.45 - k * 0.1)
			for i in 5:
				L(ci, Vector2(w * (0.3 + i * 0.1), h * 0.04), Vector2(w * (0.3 + i * 0.1), c.y - minf(w, h) * 0.2), 0.3)
			ci.draw_string(font, Vector2(w * 0.32, h * 0.92), (p.tag + "  " + p.label).strip_edges() if p != null else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.ink(0.5))
		"arm":
			var m := Geom.M
			for x in [0.6, 2.4, 4.2, 6.0]:
				if x * m < w:
					L(ci, Vector2(x * m, h * 0.65), Vector2(x * m, h * 0.95), 0.3)
			ring(ci, Vector2(w * 0.02 + 0.2 * m, h * 0.55), 0.18 * m, 0.6)
			ring(ci, Vector2(w - 0.6 * m, h * 0.35), 0.22 * m, 0.6)
		"brake":
			box(ci, Rect2(w * 0.1, h * 0.1, w * 0.8, h * 0.8), 0.5)
			ci.draw_string(font, Vector2(w * 0.14, h * 0.62), "BRK", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(6, int(h * 0.3)), Pal.ink(0.6))
		"dock":
			L(ci, Vector2(w * 0.08, 1), Vector2(w * 0.92, 1), 0.8, 1.6)
			box(ci, Rect2(w * 0.2, h * 0.25, w * 0.6, h * 0.55), 0.45)
		"engine_s":
			for i in 5:
				L(ci, Vector2(w * (0.08 + i * 0.08), h * 0.3), Vector2(w * (0.08 + i * 0.08), h * 0.7), 0.3)
			for i in 3:
				var t := 0.55 + i * 0.13
				L(ci, Vector2(w * t, h * (0.32 - i * 0.08)), Vector2(w * t, h * (0.68 + i * 0.08)), 0.25)
		"glove":
			ring(ci, Vector2(w * 0.5, h * 0.3), w * 0.32, 0.6)
			for gx in [0.32, 0.68]:
				ci.draw_polyline(PackedVector2Array([Vector2(w * gx, h * 0.45), Vector2(w * (gx + 0.06), h * 0.68), Vector2(w * gx, h * 0.9)]), Pal.ink(0.5), 1.0, true)
		"ladder":
			L(ci, Vector2(w * 0.15, 0), Vector2(w * 0.15, h), 0.55)
			L(ci, Vector2(w * 0.85, 0), Vector2(w * 0.85, h), 0.55)
			var k := 0.2 * Geom.M
			while k < h:
				L(ci, Vector2(w * 0.15, k), Vector2(w * 0.85, k), 0.4)
				k += 0.3 * Geom.M
		"suit":
			ci.draw_arc(Vector2(w * 0.5, h * 0.09), w * 0.36, 0.0, TAU, 20, Pal.ink(0.7), 1.0, true)
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.1, h * 0.22), Vector2(w * 0.9, h * 0.22), Vector2(w * 0.8, h * 0.62), Vector2(w * 0.62, h), Vector2(w * 0.38, h), Vector2(w * 0.2, h * 0.62), Vector2(w * 0.1, h * 0.22)]), Pal.ink(0.6), 1.0, true)
			ci.draw_rect(Rect2(w * 0.25, h * 0.28, w * 0.5, h * 0.17), Pal.tint(Pal.AIR, 0.7, 1.0), false, 1.0)
		"grating":
			var n := maxi(3, int(w / 9.0))
			for i in range(1, n):
				L(ci, Vector2(w * i / n, 1), Vector2(w * i / n, h - 1), 0.25)
		"harness":
			L(ci, Vector2(0, h * 0.35), Vector2(w, h * 0.35), 0.45)
			L(ci, Vector2(0, h * 0.7), Vector2(w, h * 0.7), 0.3)
			var k := 14.0
			while k < w - 4:
				ring(ci, Vector2(k, h * 0.5), minf(h * 0.32, 3.0), 0.55)
				k += 46.0
		"eng_front":
			for i in 4:
				L(ci, Vector2(w * 0.15, h * (0.2 + i * 0.2)), Vector2(w * 0.85, h * (0.2 + i * 0.2)), 0.3)
			ring(ci, Vector2(w * 0.5, h * 0.5), h * 0.18, 0.5)
		"shroud":
			for i in 8:
				L(ci, Vector2(w * (0.06 + i * 0.12), 2), Vector2(w * (0.06 + i * 0.12), h - 2), 0.25)
		"bed":
			# a stretcher on its frame, the monitor on its arm
			box(ci, Rect2(w * 0.04, h * 0.42, w * 0.7, h * 0.14), 0.5)
			L(ci, Vector2(w * 0.1, h * 0.56), Vector2(w * 0.1, h * 0.96), 0.4)
			L(ci, Vector2(w * 0.68, h * 0.56), Vector2(w * 0.68, h * 0.96), 0.4)
			box(ci, Rect2(w * 0.78, h * 0.06, w * 0.2, h * 0.3), 0.5)
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.8, h * 0.22), Vector2(w * 0.85, h * 0.22), Vector2(w * 0.88, h * 0.12), Vector2(w * 0.91, h * 0.3), Vector2(w * 0.96, h * 0.22)]), Pal.ink(0.55), 1.0)
			L(ci, Vector2(w * 0.88, h * 0.36), Vector2(w * 0.88, h * 0.96), 0.3)
		"op_table":
			box(ci, Rect2(w * 0.08, h * 0.5, w * 0.84, h * 0.1), 0.5)
			L(ci, Vector2(w * 0.5, h * 0.6), Vector2(w * 0.5, h * 0.96), 0.45, 1.4)
			L(ci, Vector2(w * 0.3, h * 0.96), Vector2(w * 0.7, h * 0.96), 0.45)
			ci.draw_arc(Vector2(w * 0.5, h * 0.18), w * 0.2, PI, TAU, 16, Pal.ink(0.5), 1.0, true)
			L(ci, Vector2(w * 0.3, h * 0.18), Vector2(w * 0.7, h * 0.18), 0.5)
			L(ci, Vector2(w * 0.5, h * 0.18 - w * 0.2), Vector2(w * 0.5, 0), 0.3)
		"freezer":
			box(ci, Rect2(w * 0.04, h * 0.04, w * 0.92, h * 0.92), 0.5)
			for k in 3:
				box(ci, Rect2(w * (0.1 + k * 0.29), h * 0.14, w * 0.24, h * 0.66), 0.3)
			for k in 4:
				L(ci, Vector2(w * (0.14 + k * 0.22), h * 0.86), Vector2(w * (0.2 + k * 0.22), h * 0.92), 0.35)
			ci.draw_string(font, Vector2(w * 0.12, h * 0.52), "-80°C", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.ink(0.45))
		"biobox":
			box(ci, Rect2(w * 0.06, h * 0.12, w * 0.88, h * 0.82), 0.6, 1.2)
			L(ci, Vector2(w * 0.02, h * 0.12), Vector2(w * 0.98, h * 0.12), 0.6, 1.6)
			ring(ci, Vector2(w * 0.5, h * 0.54), minf(w, h) * 0.2, 0.55)
			ci.draw_string(font, Vector2(w * 0.24, h * 0.92), "BIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.ink(0.55))
		"monitor":
			box(ci, Rect2(w * 0.06, h * 0.06, w * 0.88, h * 0.62), 0.5)
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.12, h * 0.4), Vector2(w * 0.4, h * 0.4), Vector2(w * 0.48, h * 0.16), Vector2(w * 0.56, h * 0.6), Vector2(w * 0.62, h * 0.4), Vector2(w * 0.88, h * 0.4)]), Pal.ink(0.5), 1.0)
			L(ci, Vector2(w * 0.5, h * 0.68), Vector2(w * 0.5, h * 0.96), 0.35)
		"cryotank":
			# the inner tank: its long walls, the pump tower down one end, the spray ring along the top, the level gauge's well
			var rr := minf(h * 0.3, w * 0.12)
			box(ci, Rect2(rr, h * 0.06, w - 2.0 * rr, h * 0.88), 0.25)
			L(ci, Vector2(w * 0.12, h * 0.08), Vector2(w * 0.12, h * 0.9), 0.45, 1.4)
			L(ci, Vector2(w * 0.14, h * 0.08), Vector2(w * 0.14, h * 0.9), 0.3)
			box(ci, Rect2(w * 0.1, h * 0.84, w * 0.06, h * 0.08), 0.5)
			for k in 9:
				ci.draw_circle(Vector2(w * (0.2 + k * 0.075), h * 0.12), 1.3, Pal.ink(0.4))
			L(ci, Vector2(w * 0.88, h * 0.1), Vector2(w * 0.88, h * 0.9), 0.3)
			for k in 6:
				L(ci, Vector2(w * 0.86, h * (0.2 + k * 0.12)), Vector2(w * 0.9, h * (0.2 + k * 0.12)), 0.35)
			L(ci, Vector2(w * 0.2, h * 0.55), Vector2(w * 0.8, h * 0.55), 0.18)
			ci.draw_string(font, Vector2(w * 0.4, h * 0.48), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(h * 0.1)), Pal.ink(0.5))
			ci.draw_string(font, Vector2(w * 0.4, h * 0.66), "-253°C" if p != null and p.name_key == "p_lh2_tank" else "-163°C", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(h * 0.07)), Pal.ink(0.4))
		"guard":
			L(ci, Vector2(w * 0.5, 3), Vector2(w * 0.45, h - 3), 0.3)
		"uav":
			# a maintenance drone parked in its bay: the body ring, four rotor wells, the sensor eye
			var c := Vector2(w * 0.5, h * 0.5)
			ci.draw_arc(c, minf(w, h) * 0.34, PI / 8.0, TAU + PI / 8.0, 9, Pal.ink(0.6), 1.2, true)
			ring(ci, c, minf(w, h) * 0.12, 0.5)
			for q in [Vector2(0.14, 0.24), Vector2(0.86, 0.24), Vector2(0.14, 0.76), Vector2(0.86, 0.76)]:
				var rc := Vector2(w * q.x, h * q.y)
				ring(ci, rc, minf(w * 0.11, h * 0.2), 0.4)
				L(ci, rc, c + (rc - c) * 0.45, 0.3)
			ci.draw_string(font, Vector2(w * 0.38, h * 0.95), p.label if p != null else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.ink(0.45))
		"lift":
			# a scissor lift: its deck along the top, the crossed legs, the base frame
			L(ci, Vector2(2, h * 0.12), Vector2(w - 2, h * 0.12), 0.55, 1.4)
			L(ci, Vector2(2, h * 0.9), Vector2(w - 2, h * 0.9), 0.5)
			var n := maxi(2, int(w / 40.0))
			for i in n:
				var x0 := w * (0.04 + 0.92 * i / n)
				var x1 := w * (0.04 + 0.92 * (i + 1) / n)
				L(ci, Vector2(x0, h * 0.15), Vector2(x1, h * 0.87), 0.4)
				L(ci, Vector2(x0, h * 0.87), Vector2(x1, h * 0.15), 0.4)
