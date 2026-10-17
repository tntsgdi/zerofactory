class_name Art
# Line art for named equipment, drawn inside its own rectangle (0,0)-(w,h).
# White ink only; the heat orange is never used here.

static func L(ci: CanvasItem, a: Vector2, b: Vector2, al: float = 0.5, wd: float = 1.0) -> void:
	ci.draw_line(a, b, Pal.ink(al), wd, true)


static func box(ci: CanvasItem, r: Rect2, al: float = 0.5, wd: float = 1.0) -> void:
	ci.draw_rect(r, Pal.ink(al), false, wd)


static func ring(ci: CanvasItem, c: Vector2, r: float, al: float = 0.5, wd: float = 1.0) -> void:
	ci.draw_arc(c, r, 0.0, TAU, 28, Pal.ink(al), wd, true)


static func draw(ci: CanvasItem, art: String, s: Vector2, p, font: Font) -> void:
	var w := s.x
	var h := s.y
	match art:
		"window":
			pass
		"nav":
			box(ci, Rect2(w * 0.08, h * 0.12, w * 0.5, h * 0.42), 0.6)
			for i in 3:
				L(ci, Vector2(w * 0.14, h * (0.22 + i * 0.1)), Vector2(w * (0.3 + i * 0.07), h * (0.22 + i * 0.1)), 0.45)
			for i in 3:
				ring(ci, Vector2(w * (0.68 + i * 0.1), h * 0.3), w * 0.035, 0.5)
			for i in 7:
				L(ci, Vector2(w * (0.1 + i * 0.12), h * 0.7), Vector2(w * (0.1 + i * 0.12), h * 0.86), 0.3)
		"nav_rack":
			for i in 5:
				box(ci, Rect2(w * 0.12, h * (0.06 + i * 0.18), w * 0.76, h * 0.14), 0.4)
				ci.draw_circle(Vector2(w * 0.76, h * (0.13 + i * 0.18)), 1.3, Pal.ink(0.55))
				L(ci, Vector2(w * 0.2, h * (0.13 + i * 0.18)), Vector2(w * 0.5, h * (0.13 + i * 0.18)), 0.3)
		"seat":
			# the piece itself is the couch's outline; here only its seams, the harness and the side stick
			L(ci, Vector2(w * 0.83, h * 0.17), Vector2(w * 0.97, h * 0.2), 0.4)
			L(ci, Vector2(w * 0.06, h * 0.69), Vector2(w * 0.62, h * 0.68), 0.3)
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.88, h * 0.24), Vector2(w * 0.42, h * 0.5), Vector2(w * 0.2, h * 0.64)]), Pal.ink(0.35), 1.0, true)
			L(ci, Vector2(w * 0.12, h * 0.64), Vector2(w * 0.1, h * 0.5), 0.5, 1.2)
			ci.draw_circle(Vector2(w * 0.1, h * 0.49), 1.6, Pal.ink(0.5))
		"overhead":
			for i in 7:
				ci.draw_circle(Vector2(w * (0.1 + i * 0.13), h * 0.55), 1.4, Pal.ink(0.55))
			L(ci, Vector2(w * 0.05, h * 0.85), Vector2(w * 0.95, h * 0.85), 0.3)
		"o2cab":
			box(ci, Rect2(w * 0.08, h * 0.06, w * 0.84, h * 0.88), 0.4)
			var rr := w * 0.24
			ci.draw_arc(Vector2(w * 0.5, h * 0.18 + rr), rr, PI, TAU, 12, Pal.ink(0.55), 1.0, true)
			L(ci, Vector2(w * 0.26, h * 0.18 + rr), Vector2(w * 0.26, h * 0.86), 0.55)
			L(ci, Vector2(w * 0.74, h * 0.18 + rr), Vector2(w * 0.74, h * 0.86), 0.55)
			ci.draw_string(font, Vector2(w * 0.3, h * 0.66), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.ink(0.5))
		"console":
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.1, h), Vector2(w * 0.1, h * 0.45), Vector2(w * 0.95, h * 0.2), Vector2(w * 0.95, h)]), Pal.ink(0.5), 1.0)
			for i in 4:
				ci.draw_circle(Vector2(w * (0.25 + i * 0.17), h * (0.42 - i * 0.05)), 1.6, Pal.ink(0.55))
			L(ci, Vector2(w * 0.2, h * 0.62), Vector2(w * 0.85, h * 0.45), 0.3)
		"blackbox":
			box(ci, Rect2(w * 0.12, h * 0.15, w * 0.76, h * 0.7), 0.7)
			for i in 3:
				L(ci, Vector2(w * 0.12, h * (0.3 + i * 0.18)), Vector2(w * 0.88, h * (0.3 + i * 0.18)), 0.55, 1.6)
			ci.draw_string(font, Vector2(w * 0.14, h * 0.12), "FDR", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.ink(0.55))
		"cover":
			L(ci, Vector2(w * 0.2, h * 0.5), Vector2(w * 0.8, h * 0.5), 0.3)
			ci.draw_string(font, Vector2(w * 0.12, h * 0.3), "SERVICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.ink(0.35))
		"gastank":
			var r := w * 0.42
			ci.draw_arc(Vector2(w * 0.5, r + 2), r, PI, TAU, 18, Pal.ink(0.55), 1.0, true)
			ci.draw_arc(Vector2(w * 0.5, h - r - 2), r, 0.0, PI, 18, Pal.ink(0.55), 1.0, true)
			L(ci, Vector2(w * 0.08, r + 2), Vector2(w * 0.08, h - r - 2), 0.55)
			L(ci, Vector2(w * 0.92, r + 2), Vector2(w * 0.92, h - r - 2), 0.55)
			for i in 2:
				L(ci, Vector2(w * 0.08, h * (0.38 + i * 0.24)), Vector2(w * 0.92, h * (0.38 + i * 0.24)), 0.3)
			ci.draw_string(font, Vector2(w * 0.22, h * 0.56), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.ink(0.45))
		"env":
			ring(ci, Vector2(w * 0.3, h * 0.45), h * 0.26, 0.55)
			for i in 6:
				var a := TAU * i / 6.0
				L(ci, Vector2(w * 0.3, h * 0.45), Vector2(w * 0.3, h * 0.45) + Vector2.from_angle(a) * h * 0.22, 0.35)
			for i in 4:
				L(ci, Vector2(w * 0.62, h * (0.22 + i * 0.16)), Vector2(w * 0.9, h * (0.22 + i * 0.16)), 0.4)
		"bunk":
			L(ci, Vector2(4, h * 0.35), Vector2(w - 4, h * 0.35), 0.35)
			box(ci, Rect2(6, h * 0.05, w * 0.18, h * 0.28), 0.3)
		"cargo":
			var n := int(w / 16.0)
			for i in range(1, n):
				L(ci, Vector2(w * i / n, 3), Vector2(w * i / n, h - 3), 0.22)
			box(ci, Rect2(3, 3, w - 6, h - 6), 0.4)
			ci.draw_string(font, Vector2(w * 0.08, h * 0.2), p.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Pal.ink(0.7))
			ci.draw_string(font, Vector2(w * 0.08, h * 0.2 + 13), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.ink(0.4))
			if p.fragile >= 0.85:
				ci.draw_string(font, Vector2(w * 0.08, h * 0.9), "FRAGILE ▲▲", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.ink(0.5))
		"hook":
			L(ci, Vector2(w * 0.5, 0), Vector2(w * 0.5, h * 0.7), 0.5)
			ci.draw_arc(Vector2(w * 0.5, h * 0.78), w * 0.22, -0.3, PI + 0.6, 12, Pal.ink(0.6), 1.2, true)
		"lamp":
			L(ci, Vector2(3, h * 0.6), Vector2(w - 3, h * 0.6), 0.5)
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
		"locker":
			box(ci, Rect2(w * 0.08, h * 0.05, w * 0.84, h * 0.9), 0.45)
			L(ci, Vector2(w * 0.75, h * 0.35), Vector2(w * 0.75, h * 0.55), 0.6, 1.4)
			for k in 3:
				L(ci, Vector2(w * 0.15, h * (0.72 + k * 0.06)), Vector2(w * 0.6, h * (0.72 + k * 0.06)), 0.3)
		"rcs_quad":
			for dx in [0.2, 0.5, 0.8]:
				L(ci, Vector2(w * dx, h * 0.2), Vector2(w * dx, h * 0.8), 0.45)
		"reel":
			ring(ci, Vector2(w * 0.5, h * 0.5), minf(w, h) * 0.38, 0.55)
			ring(ci, Vector2(w * 0.5, h * 0.5), minf(w, h) * 0.12, 0.45)
		"sphere_tank":
			ring(ci, Vector2(w * 0.5, h * 0.5), w * 0.36, 0.45)
			L(ci, Vector2(w * 0.14, h * 0.5), Vector2(w * 0.86, h * 0.5), 0.3)
			ci.draw_string(font, Vector2(w * 0.3, h * 0.42), p.label, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(7, int(w * 0.2)), Pal.ink(0.6))
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
		"insp":
			box(ci, Rect2(w * 0.15, h * 0.08, w * 0.7, h * 0.84), 0.45)
			for i in 3:
				L(ci, Vector2(w * 0.28, h * (0.25 + i * 0.12)), Vector2(w * 0.72, h * (0.25 + i * 0.12)), 0.3)
			ring(ci, Vector2(w * 0.5, h * 0.75), w * 0.14, 0.55)
		"gen":
			for i in 3:
				var cx := w * (0.2 + i * 0.22)
				box(ci, Rect2(cx - w * 0.08, h * 0.18, w * 0.16, h * 0.6), 0.45)
				for k in 5:
					L(ci, Vector2(cx - w * 0.08, h * (0.26 + k * 0.1)), Vector2(cx + w * 0.08, h * (0.26 + k * 0.1)), 0.2)
			box(ci, Rect2(w * 0.08, h * 0.82, w * 0.84, h * 0.1), 0.35)
			ci.draw_string(font, Vector2(w * 0.08, h * 0.12), (p.tag + "  " + p.label).strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.ink(0.6))
			ring(ci, Vector2(w * 0.87, h * 0.25), 4.0, 0.6)
		"battery":
			for i in 4:
				for k in 2:
					box(ci, Rect2(w * (0.08 + i * 0.22), h * (0.2 + k * 0.36), w * 0.18, h * 0.3), 0.35)
			ci.draw_string(font, Vector2(w * 0.08, h * 0.15), p.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.ink(0.6))
		"cap":
			var r := w * 0.42
			ci.draw_arc(Vector2(w * 0.5, r + 3), r, PI, TAU, 14, Pal.ink(0.5), 1.0, true)
			for i in 4:
				L(ci, Vector2(w * 0.1, h * (0.35 + i * 0.14)), Vector2(w * 0.9, h * (0.35 + i * 0.14)), 0.3)
			ci.draw_string(font, Vector2(w * 0.1, h * 0.95), "HV", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Pal.ink(0.6))
		"swb":
			for i in 6:
				box(ci, Rect2(w * 0.18, h * (0.08 + i * 0.14), w * 0.64, h * 0.09), 0.35)
				ci.draw_circle(Vector2(w * 0.7, h * (0.125 + i * 0.14)), 1.4, Pal.ink(0.5))
		"pump":
			ring(ci, Vector2(w * 0.38, h * 0.5), h * 0.3, 0.55)
			for i in 5:
				var a := TAU * i / 5.0
				ci.draw_arc(Vector2(w * 0.38, h * 0.5) + Vector2.from_angle(a) * h * 0.12, h * 0.12, a, a + 2.2, 6, Pal.ink(0.35), 1.0)
			box(ci, Rect2(w * 0.72, h * 0.25, w * 0.2, h * 0.5), 0.45)
		"cabinet":
			L(ci, Vector2(w * 0.5, 4), Vector2(w * 0.5, h - 4), 0.35)
			for i in 3:
				L(ci, Vector2(6, h * (0.3 + i * 0.22)), Vector2(w - 6, h * (0.3 + i * 0.22)), 0.2)
		"radiator":
			var n := int(w / 6.0)
			for i in range(1, n):
				L(ci, Vector2(w * i / n, 4), Vector2(w * i / n + (2.0 if i % 3 == 0 else 0.0), h - 4), 0.3)
		"module":
			box(ci, Rect2(w * 0.15, h * 0.2, w * 0.7, h * 0.6), 0.6)
			L(ci, Vector2(w * 0.3, h * 0.5), Vector2(w * 0.7, h * 0.5), 0.5)
		"panel":
			ci.draw_string(font, Vector2(4, h * 0.95), p.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Pal.ink(0.4))
		"eng_front":
			for i in 4:
				L(ci, Vector2(w * 0.15, h * (0.2 + i * 0.2)), Vector2(w * 0.85, h * (0.2 + i * 0.2)), 0.3)
			ring(ci, Vector2(w * 0.5, h * 0.5), h * 0.18, 0.5)
		"eng_core":
			for i in 7:
				L(ci, Vector2(w * (0.08 + i * 0.14), h * 0.1), Vector2(w * (0.08 + i * 0.14), h * 0.9), 0.25)
			ci.draw_polyline(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w * 0.3, h * 0.3), Vector2(w * 0.7, h * 0.3), Vector2(w, h * 0.5)]), Pal.ink(0.4), 1.0)
			ci.draw_polyline(PackedVector2Array([Vector2(0, h * 0.5), Vector2(w * 0.3, h * 0.7), Vector2(w * 0.7, h * 0.7), Vector2(w, h * 0.5)]), Pal.ink(0.4), 1.0)
		"shroud":
			for i in 8:
				L(ci, Vector2(w * (0.06 + i * 0.12), 2), Vector2(w * (0.06 + i * 0.12), h - 2), 0.25)
		"nozzle":
			for i in 5:
				var t := (i + 1) / 6.0
				var x := w * t
				var hh := lerpf(0.75, 1.5, t) / 3.0 * h
				L(ci, Vector2(x, h * 0.5 - hh * 0.96), Vector2(x, h * 0.5 + hh * 0.96), 0.22)
		"aux":
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.05, h * 0.3), Vector2(w * 0.6, h * 0.3), Vector2(w * 0.95, h * 0.1)]), Pal.ink(0.4), 1.0)
			ci.draw_polyline(PackedVector2Array([Vector2(w * 0.05, h * 0.7), Vector2(w * 0.6, h * 0.7), Vector2(w * 0.95, h * 0.9)]), Pal.ink(0.4), 1.0)
		"fueltank":
			var r := h * 0.48
			ci.draw_arc(Vector2(r + 2, h * 0.5), r, PI * 0.5, PI * 1.5, 16, Pal.ink(0.5), 1.0, true)
			ci.draw_arc(Vector2(w - r - 2, h * 0.5), r, -PI * 0.5, PI * 0.5, 16, Pal.ink(0.5), 1.0, true)
			for i in 3:
				L(ci, Vector2(w * (0.3 + i * 0.2), 3), Vector2(w * (0.3 + i * 0.2), h - 3), 0.25)
			ci.draw_string(font, Vector2(w * 0.32, h * 0.6), (p.tag + "  " + p.label).strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Pal.ink(0.5))
		"guard":
			L(ci, Vector2(w * 0.5, 3), Vector2(w * 0.45, h - 3), 0.3)
