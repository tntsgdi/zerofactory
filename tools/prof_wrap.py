"""Temporarily wrap engine callbacks with timers for profiling.
python tools/prof_wrap.py on | off
Wrapped bodies are renamed <name>__p and the wrapper calls Prof.add(key, t0).
"""
import re, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent / "scripts"
TARGETS = {
    "world.gd": ["_process", "_physics_process", "_draw_pieces", "_draw_back", "_draw_light", "_draw_cover", "_draw_lines", "_draw_heat_static"],
    "game.gd": ["_process", "_physics_process"],
    "systems.gd": ["_physics_process"],
    "hud.gd": ["_process", "_draw_hud", "_draw_add"],
    "fx.gd": ["_draw", "_draw_add", "step"],
    "tools.gd": ["step", "physics_step", "_draw", "_draw_add"],
    "dock.gd": ["_process", "_physics_process", "_draw", "_draw_add"],
    "drone.gd": ["_process", "_physics_process", "_draw", "_draw_add"],
    "free_body.gd": ["_process", "_draw_view", "_draw_heat"],
    "backdrop.gd": ["_process", "_draw"],
    "blueprint.gd": ["_process", "_draw"],
    "sfx.gd": ["_process"],
    "hauler.gd": ["_physics_process", "_process", "_draw"],
    "minimap.gd": ["_process", "_draw"],
    "arm.gd": ["_physics_process", "_process", "_draw"],
    "crane.gd": ["_physics_process", "_process", "_draw"],
    "consoles.gd": ["_process", "_draw"],
}
MARK = "# PROF-WRAP"

def on():
    for f, names in TARGETS.items():
        p = ROOT / f
        s = p.read_text(encoding="utf-8")
        if MARK in s:
            continue
        for n in names:
            m = re.search(r"^func %s\((.*?)\)( -> \w+)?:\n" % re.escape(n), s, re.M)
            if not m:
                print("missing", f, n); continue
            args = m.group(1)
            ret = m.group(2) or ""
            names_only = ", ".join(a.split(":")[0].strip() for a in args.split(",") if a.strip())
            call = "%s__p(%s)" % (n, names_only)
            if ret.strip() == "-> void" or ret == "":
                body = "\tvar __t := Time.get_ticks_usec()\n\t%s\n\tProf.add(\"%s.%s\", __t)\n" % (call, f[:-3], n)
            else:
                body = "\tvar __t := Time.get_ticks_usec()\n\tvar __r = %s\n\tProf.add(\"%s.%s\", __t)\n\treturn __r\n" % (call, f[:-3], n)
            wrapper = "func %s(%s)%s: %s\n%s\n\nfunc %s__p(%s)%s:\n" % (n, args, ret, MARK, body, n, args, ret)
            s = s[:m.start()] + wrapper + s[m.end():]
        p.write_text(s, encoding="utf-8", newline=chr(10))

def off():
    for f in TARGETS:
        p = ROOT / f
        s = p.read_text(encoding="utf-8")
        while MARK in s:
            m = re.search(r"^func (\w+)\((.*?)\)( -> \w+)?: %s\n(?:\t.*\n)+\n\nfunc \1__p\(" % re.escape(MARK), s, re.M)
            if not m:
                print("cannot unwrap", f); break
            n = m.group(1)
            s = s[:m.start()] + "func %s(" % n + s[m.end():]
        p.write_text(s, encoding="utf-8", newline=chr(10))

{"on": on, "off": off}[sys.argv[1]]()
