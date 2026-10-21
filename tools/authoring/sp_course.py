"""The seven special courses (design/新手教程与图鉴定案.md, 2026-10-20), as data for
scripts/tutorial.gd, one file per family: ships/sp_<family>_course.json.
python tools/authoring/sp_course.py

Each course: lesson 0 is the briefing (unnumbered), then one lesson per mechanism.
The first dangerous move of a lesson is stopped by the training interlock, the
second is let go wrong, and the props (and the mechanism's own state, "remod")
come back 1.5 s later. Liang's lines are the user's to write: placeholders, which
the course does not play; the task list carries every step. The terminal's lines
are system messages.
"""
import json, os

TBW = ("【待写】", "[TO BE WRITTEN]")


def t(zh, en):
    return {"zh": zh, "en": en}


def course(family, lessons, term):
    lines = {}
    ids = []
    for l in lessons:
        for st in l["steps"]:
            for k in ("in", "out"):
                ids += st.get(k, [])
            if "hint" in st:
                ids.append(st["hint"])
        g = l.get("guard", {})
        ids += g.get("lock", [])
        if g.get("say"):
            ids.append(g["say"])
    for i in ids:
        if i in term:
            lines[i] = {"who": "term", "zh": term[i][0], "en": term[i][1]}
        else:
            lines[i] = {"who": "liang", "zh": TBW[0], "en": TBW[1]}
    brief = {"id": "SP_00", "mode": "lockstep", "title": t("专项训练", "SPECIAL COURSE"), "done_flag": "SP_00_COMPLETE", "steps": [
        {"id": "brief", "text": t("看一眼训练件：按 I 可以随时查图鉴", "LOOK OVER THE RIG: I OPENS THE CODEX ANY TIME"), "tools": [], "done": {"step_t": 4.0}, "in": ["SB_in"]},
    ]}
    lines["SB_in"] = {"who": "liang", "zh": TBW[0], "en": TBW[1]}
    out = {"ship": "sp_" + family, "lines": lines, "lessons": [brief] + lessons, "rings": [], "long_ring": [], "stop_box": []}
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "..", "..", "ships", "sp_%s_course.json" % family), "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, ensure_ascii=False, indent="\t")
    print("ships/sp_%s_course.json: %d lessons, %d steps" % (family, len(out["lessons"]), sum(len(l["steps"]) for l in out["lessons"])))


ALL_TOOLS = [1, 2, 3, 4, 5]

# ---------------------------------------------------------------- stored energy
course("energy", [
    {"id": "SP_E1", "mode": "lockstep", "title": t("超导线圈：先泄能，后断冷", "THE COIL: DUMP FIRST, WARM LATER"), "done_flag": "SP_E1_COMPLETE",
     "guard": {"pieces": ["TC-1", "TC-S"], "until": {"mod_safe": "magnets"}, "lock": ["SE_lock_t", "SE_lock_l"],
               "accident": ["magnet_quench"], "reset": ["TC-1", "TC-S"], "remod": ["magnets"], "say": "SE_quench",
               "restore": {"ctrls": ["DUMP"], "readings": ["FIELD", "COILT"]}},
     "steps": [
        {"id": "field", "text": t("测量（1）：读失超保护台的储能 FIELD", "MEASURE (1): READ THE STORED FIELD AT FIELD"), "tools": [1],
         "done": {"reading": ["FIELD"]}, "in": ["SE_in1", "SE_in2"], "target": {"ctrl": "FIELD"}},
        {"id": "dump", "text": t("合上泄能开关 DUMP（4）；冷箱保持供电", "WRENCH (4): CLOSE THE DUMP SWITCH; KEEP THE COLD BOX POWERED"), "tools": [1, 4], "context": True,
         "done": {"switch": ["DUMP", True]}, "target": {"ctrl": "DUMP"}},
        {"id": "wait", "text": t("等储能降到 5% 以下（按住 = 加速）", "WAIT: STORED FIELD UNDER 5 % (HOLD = TO SPEED UP)"), "tools": [1, 4],
         "done": {"mod": ["magnets", "field", "<", 5.0]}, "out": ["SE_safe_t"], "warp": True},
        {"id": "free", "text": t("拆下线圈 TC-1 的螺栓（4）", "WRENCH (4): UNBOLT COIL TC-1"), "tools": [3, 4], "context": True,
         "done": {"free": "TC-1"}, "target": {"piece": "TC-1"}},
        {"id": "deliver", "text": t("线圈完整送进设备回收口", "THE COIL, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["TC-1", "any"]}, "out": ["SE_coil_done"], "target": {"zone": "equip"}},
    ]},
    {"id": "SP_E2", "mode": "lockstep", "title": t("飞轮：先冷却，后刹车", "THE FLYWHEEL: COOLING, THEN BRAKE"), "done_flag": "SP_E2_COMPLETE",
     "guard": {"pieces": ["FW-1"], "until": {"mod_safe": "flywheel"}, "lock": ["SF_lock_t", "SF_lock_l"],
               "accident": ["wheel_loose", "brake_burn"], "reset": ["FW-1", "BRK-1"], "remod": ["flywheel"], "say": "SF_bad",
               "restore": {"ctrls": ["BR-1", "CV-1"], "readings": ["RPM-1"]}},
     "steps": [
        {"id": "rpm", "text": t("测量（1）：读转速表 RPM-1", "MEASURE (1): READ THE TACHOMETER RPM-1"), "tools": [1],
         "done": {"reading": ["RPM-1"]}, "in": ["SF_in1", "SF_in2"], "target": {"ctrl": "RPM-1"}},
        {"id": "cool", "text": t("先打开刹车冷却 CV-1（4）", "WRENCH (4): BRAKE COOLING CV-1 ON FIRST"), "tools": [1, 4], "context": True,
         "done": {"switch": ["CV-1", True]}, "target": {"ctrl": "CV-1"}},
        {"id": "brake", "text": t("再上刹车 BR-1（4）", "WRENCH (4): THEN THE BRAKE BR-1"), "tools": [1, 4], "context": True,
         "done": {"switch": ["BR-1", True]}, "target": {"ctrl": "BR-1"}},
        {"id": "wait", "text": t("等转速降到 300 rpm 以下（按住 = 加速）", "WAIT: UNDER 300 rpm (HOLD = TO SPEED UP)"), "tools": [1, 4],
         "done": {"mod": ["flywheel", "max_rpm", "<", 300.0]}, "out": ["SF_safe_t"], "warp": True},
        {"id": "free", "text": t("拆下飞轮 FW-1 的螺栓（4）", "WRENCH (4): UNBOLT FLYWHEEL FW-1"), "tools": [3, 4], "context": True,
         "done": {"free": "FW-1"}, "target": {"piece": "FW-1"}},
        {"id": "deliver", "text": t("飞轮完整送进设备回收口", "THE FLYWHEEL, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["FW-1", "any"]}, "out": ["SF_done"], "target": {"zone": "equip"}},
    ]},
], {
    "SE_lock_t": ("训练安全联锁启动：线圈仍储有磁能。", "TRAINING INTERLOCK: THE COIL STILL HOLDS ITS FIELD."),
    "SE_safe_t": ("储能已降到安全值。", "STORED FIELD BELOW SAFE."),
    "SF_lock_t": ("训练安全联锁启动：飞轮仍在高速旋转。", "TRAINING INTERLOCK: THE FLYWHEEL IS STILL SPINNING."),
    "SF_safe_t": ("飞轮转速已降到安全值。", "FLYWHEEL BELOW SAFE SPEED."),
})

# ---------------------------------------------------------------- cryogenics
course("cryo", [
    {"id": "SP_C1", "mode": "lockstep", "title": t("冻住的安全阀：边制冷边抽", "A FROZEN RELIEF: DRAW IT DOWN COLD"), "done_flag": "SP_C1_COMPLETE",
     "guard": {"pieces": ["TK-1", "RV-1"], "until": {"mod_safe": "boiloff"}, "lock": ["SC_lock_t", "SC_lock_l"],
               "accident": ["tank_burst", "tank_vent"], "reset": ["TK-1", "RV-1"], "remod": ["boiloff"], "say": "SC_bad",
               "restore": {"ctrls": ["RVH-1"], "hoses": ["PT-1"], "readings": ["TP-1", "VT-1"]}},
     "steps": [
        {"id": "kpa", "text": t("测量（1）：读罐压 TP-1（它自己在升）", "MEASURE (1): TANK PRESSURE TP-1 (IT CLIMBS BY ITSELF)"), "tools": [1],
         "done": {"reading": ["TP-1"]}, "in": ["SC_in1", "SC_in2"], "target": {"ctrl": "TP-1"}},
        {"id": "valve", "text": t("测量（1）：读安全阀温度 VT-1", "MEASURE (1): RELIEF VALVE TEMPERATURE VT-1"), "tools": [1],
         "done": {"reading": ["VT-1"]}, "out": ["SC_frozen"], "target": {"ctrl": "VT-1"}},
        {"id": "thaw", "text": t("阀冻住了：打开安全阀加热 RVH-1（4），冷头保持供电", "FROZEN: VALVE HEATER RVH-1 ON (4); CRYOCOOLER STAYS POWERED"), "tools": [1, 4], "context": True,
         "done": {"switch": ["RVH-1", True]}, "target": {"ctrl": "RVH-1"}},
        {"id": "hose", "text": t("气液回收（5）：软管接 PT-1 抽液", "HOSE (5): ON PT-1, DRAW THE CARGO OFF"), "tools": [1, 5],
         "done": {"hose": "PT-1"}, "target": {"ctrl": "PT-1"}},
        {"id": "draw", "text": t("等罐抽空（按住 = 加速）", "WAIT: THE TANK EMPTY (HOLD = TO SPEED UP)"), "tools": [1, 5],
         "done": {"mod_safe": "boiloff"}, "out": ["SC_safe_t"], "warp": True},
        {"id": "free", "text": t("拆下罐 TK-1 的螺栓（4）", "WRENCH (4): UNBOLT TANK TK-1"), "tools": [3, 4], "context": True,
         "done": {"free": "TK-1"}, "target": {"piece": "TK-1"}},
        {"id": "deliver", "text": t("空罐送进回收口", "THE EMPTY TANK TO A MOUTH"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["TK-1", "any"]}, "out": ["SC_done"], "target": {"piece": "TK-1"}},
    ]},
    {"id": "SP_C2", "mode": "lockstep", "title": t("稀释制冷机：按序回温", "THE DILUTION FRIDGE: WARM IT IN ORDER"), "done_flag": "SP_C2_COMPLETE",
     "guard": {"pieces": ["QPU", "STG-MXC", "STG-4K", "STG-50K"], "until": {"mod_safe": "dilution"}, "lock": ["SD_lock_t", "SD_lock_l"],
               "accident": ["mix_boil", "qpu_shock", "qpu_brittle", "qpu_vibration"], "reset": ["QPU", "STG-MXC", "STG-4K", "STG-50K"], "remod": ["dilution"], "say": "SD_bad",
               "restore": {"gas": ["MIX"], "ctrls": ["CIRC", "PT", "HEAT", "VI-LOCK"], "hoses": ["MIXP"], "readings": ["MXT", "MIXP"]}},
     "steps": [
        {"id": "mxt", "text": t("测量（1）：读混合室温度 MXT", "MEASURE (1): MIXING CHAMBER MXT"), "tools": [1],
         "done": {"reading": ["MXT"]}, "in": ["SD_in1", "SD_in2"], "target": {"ctrl": "MXT"}},
        {"id": "circ", "text": t("① 停循环泵 CIRC（4）", "① CIRCULATION CIRC OFF (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["CIRC", False]}, "target": {"ctrl": "CIRC"}},
        {"id": "mix", "text": t("② 软管接 MIXP 回收混合气，压力降到 20 kPa 以下（5）", "② HOSE ON MIXP: RECOVER THE MIXTURE BELOW 20 kPa (5)"), "tools": [1, 5],
         "done": {"P": ["MIX", "<", 20.0]}, "target": {"ctrl": "MIXP"}, "warp": True},
        {"id": "pt", "text": t("③ 停脉管冷头 PT（4）", "③ PULSE TUBE PT OFF (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["PT", False]}, "target": {"ctrl": "PT"}},
        {"id": "warm", "text": t("④ 等混合室自己回温过 30 K（按住 = 加速）", "④ WAIT: IT WARMS PAST 30 K BY ITSELF (HOLD = TO SPEED UP)"), "tools": [1],
         "done": {"mod": ["dilution", "mxc_temp", ">", 32.0]}, "warp": True},
        {"id": "heat", "text": t("⑤ 现在才开加热 HEAT（4）", "⑤ ONLY NOW THE HEATERS HEAT ON (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["HEAT", True]}, "target": {"ctrl": "HEAT"}},
        {"id": "room", "text": t("⑥ 等回到 250 K 以上（按住 = 加速）", "⑥ WAIT: ABOVE 250 K (HOLD = TO SPEED UP)"), "tools": [1],
         "done": {"mod": ["dilution", "mxc_temp", ">", 252.0]}, "warp": True},
        {"id": "lock", "text": t("⑦ 锁住隔振台 VI-LOCK（4）", "⑦ LOCK THE ISOLATION TABLE VI-LOCK (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["VI-LOCK", True]}, "out": ["SD_safe_t"], "target": {"ctrl": "VI-LOCK"}},
        {"id": "free", "text": t("拆下芯片封装 QPU（4）", "WRENCH (4): UNBOLT THE CHIP PACKAGE QPU"), "tools": [3, 4], "context": True,
         "done": {"free": "QPU"}, "target": {"piece": "QPU"}},
        {"id": "deliver", "text": t("芯片完整送进设备回收口", "THE CHIP, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["QPU", "any"]}, "out": ["SD_done"], "target": {"zone": "equip"}, "exit": [2.0, 0.0]},
    ]},
], {
    "SC_lock_t": ("训练安全联锁启动：罐内仍有货物，安全阀未确认。", "TRAINING INTERLOCK: CARGO STILL ABOARD, RELIEF VALVE NOT VERIFIED."),
    "SC_safe_t": ("罐已抽空，安全阀已解冻。", "TANK EMPTY, RELIEF VALVE THAWED."),
    "SD_lock_t": ("训练安全联锁启动：制冷机未完成回温。", "TRAINING INTERLOCK: THE FRIDGE IS NOT WARMED UP."),
    "SD_safe_t": ("回温完成，隔振台已锁定。", "WARM-UP COMPLETE, TABLE LOCKED."),
})

# ---------------------------------------------------------------- fluids under pressure
course("fluid", [
    {"id": "SP_F1", "mode": "lockstep", "title": t("钻杆：泄扭、泄压、卡瓦、自上而下", "THE STRING: TORQUE, MUD, SLIPS, TOP DOWN"), "done_flag": "SP_F1_COMPLETE",
     "guard": {"pieces": ["J-1", "J-2"], "until": {"mod_safe": "drillstring"}, "lock": ["SR_lock_t", "SR_lock_l"],
               "accident": ["drill_whip", "mud_blowout", "drill_drop"], "reset": ["J-1", "J-2", "STP"], "remod": ["drillstring"], "say": "SR_bad",
               "restore": {"ctrls": ["TQB", "SLIP-1", "SLIP-2"], "hoses": ["PMUD"], "readings": ["TQ", "MUDP"]}},
     "steps": [
        {"id": "tq", "text": t("测量（1）：读扭矩表 TQ", "MEASURE (1): THE TORQUE GAUGE TQ"), "tools": [1],
         "done": {"reading": ["TQ"]}, "in": ["SR_in1", "SR_in2"], "target": {"ctrl": "TQ"}},
        {"id": "bleed", "text": t("① 松转盘刹车泄扭：TQB（4）", "① RELEASE THE ROTARY BRAKE: TQB (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["TQB", True]}, "target": {"ctrl": "TQB"}},
        {"id": "torque", "text": t("等扭矩降到 5% 以下（按住 = 加速）", "WAIT: TORQUE UNDER 5 % (HOLD = TO SPEED UP)"), "tools": [1, 4],
         "done": {"mod": ["drillstring", "torque_pct", "<", 5.0]}, "warp": True},
        {"id": "mudp", "text": t("测量（1）：读泥浆压力 MUDP", "MEASURE (1): MUD PRESSURE MUDP"), "tools": [1],
         "done": {"reading": ["MUDP"]}, "target": {"ctrl": "MUDP"}},
        {"id": "mud", "text": t("② 软管接立管 PMUD 放泥浆（可回收）（5）", "② HOSE ON THE STANDPIPE PMUD: DRAIN THE MUD (IT SELLS) (5)"), "tools": [1, 5],
         "done": {"mod": ["drillstring", "mud_level", "<", 0.05]}, "target": {"ctrl": "PMUD"}, "warp": True},
        {"id": "slips", "text": t("③ 坐好两副卡瓦 SLIP-1、SLIP-2（4）", "③ SET BOTH SLIPS, SLIP-1 AND SLIP-2 (4)"), "tools": [1, 4], "context": True,
         "done": {"all": [{"switch": ["SLIP-1", True]}, {"switch": ["SLIP-2", True]}]}, "out": ["SR_safe_t"], "target": {"ctrl": "SLIP-1"}},
        {"id": "free1", "text": t("④ 从最上面卸起：拆下立根 J-1（4）", "④ TOP DOWN: BREAK OUT STAND J-1 (4)"), "tools": [3, 4], "context": True,
         "done": {"free": "J-1"}, "target": {"piece": "J-1"}},
        {"id": "deliver1", "text": t("J-1 送进设备回收口", "J-1 TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["J-1", "any"]}, "target": {"zone": "equip"}, "exit": [2.2, 0.0], "lane": -7.2},
        {"id": "free2", "text": t("再拆下 J-2（4）", "THEN J-2 (4)"), "tools": [3, 4], "context": True,
         "done": {"free": "J-2"}, "target": {"piece": "J-2"}},
        {"id": "deliver2", "text": t("J-2 送进设备回收口", "J-2 TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["J-2", "any"]}, "out": ["SR_done"], "target": {"zone": "equip"}, "exit": [2.2, 0.0], "lane": -7.2},
    ]},
    {"id": "SP_F2", "mode": "lockstep", "title": t("交叉连通罐：带压抽，抽完就停", "CROSS-CONNECTED TANKS: DRAW UNDER PRESSURE, STOP WHEN DRY"), "done_flag": "SP_F2_COMPLETE",
     "guard": {"pieces": ["T-1", "T-2"], "until": {"mod": ["tanknet", "fuel_left", "<", 0.015]}, "lock": ["SX_lock_t", "SX_lock_l"],
               "accident": ["tank_buckled", "pump_dry"], "reset": ["T-1", "T-2", "PUMP-M"], "remod": ["tanknet"], "say": "SX_bad",
               "restore": {"gas": ["TU-1", "TU-2", "NB"], "ctrls": ["XV-1", "XV-2", "PV-1", "PV-2"], "hoses": ["PR", "TV-1", "TV-2"]}},
     "steps": [
        {"id": "ullage", "text": t("测量（1）：读罐顶气压 TV-1（氮气增压保着它）", "MEASURE (1): ULLAGE PRESSURE TV-1 (THE NITROGEN HOLDS IT UP)"), "tools": [1],
         "done": {"reading": ["TV-1"]}, "in": ["SX_in1", "SX_in2"], "target": {"ctrl": "TV-1"}},
        {"id": "cross", "text": t("① 打开两只罐的连通阀 XV-1、XV-2（4）", "① OPEN BOTH CROSSOVERS XV-1 AND XV-2 (4)"), "tools": [1, 4], "context": True,
         "done": {"all": [{"switch": ["XV-1", True]}, {"switch": ["XV-2", True]}]}, "target": {"ctrl": "XV-1"}},
        {"id": "draw", "text": t("② 增压保持打开，软管接主泵 PR 抽总管（5，按住 = 加速）", "② PRESSURISATION STAYS ON. HOSE ON PR, DRAW IT OFF (5)"), "tools": [1, 5],
         "done": {"mod": ["tanknet", "fuel_left", "<", 0.015]}, "target": {"ctrl": "PR"}, "warp": True},
        {"id": "stop", "text": t("③ 抽完立刻摘下软管（再点一次 PR），别让泵干转", "③ DRY NOW: HOSE OFF PR AT ONCE, OR THE PUMP RUNS DRY"), "tools": [1, 5],
         "done": {"no_hose": "PR"}, "out": ["SX_safe_t"], "target": {"ctrl": "PR"}},
        {"id": "free", "text": t("拆下罐 T-1（4）", "WRENCH (4): FREE TANK T-1"), "tools": [3, 4], "context": True,
         "done": {"free": "T-1"}, "target": {"piece": "T-1"}},
        {"id": "deliver", "text": t("空罐送进回收口", "THE EMPTY TANK TO A MOUTH"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["T-1", "any"]}, "out": ["SX_done"], "target": {"piece": "T-1"}, "lane": -7.2},
    ]},
], {
    "SR_lock_t": ("训练安全联锁启动：钻杆仍有扭矩、压力或卡瓦未坐。", "TRAINING INTERLOCK: TORQUE, MUD OR OPEN SLIPS ON THE STRING."),
    "SR_safe_t": ("钻杆已泄扭泄压，卡瓦已坐。", "STRING BLED, SLIPS SET."),
    "SX_lock_t": ("训练安全联锁启动：罐内仍有推进剂。", "TRAINING INTERLOCK: PROPELLANT STILL IN THE TANKS."),
    "SX_safe_t": ("推进剂已抽完。", "PROPELLANT DRAWN OFF."),
})

# ---------------------------------------------------------------- atmosphere, fire, contamination
course("atmos", [
    {"id": "SP_A1", "mode": "lockstep", "title": t("富氧舱：先换气，再开口", "OXYGEN-RICH: VENT IT, THEN OPEN IT"), "done_flag": "SP_A1_COMPLETE",
     "guard": {"pieces": ["OX-T", "OX-L", "OX-R", "OX-B"], "until": {"P": ["OX", "<", 5.0]}, "lock": ["SO_lock_t", "SO_lock_l"],
               "accident": ["o2_fire", "blowout"], "reset": ["OX-T", "GL-1", "PL-1"], "remod": ["atmos"], "say": "SO_bad",
               "restore": {"gas": ["OX"], "hoses": ["G-OX"], "readings": ["O2-1", "G-OX"]}},
     "steps": [
        {"id": "o2", "text": t("测量（1）：读氧浓度 O2-1", "MEASURE (1): OXYGEN AT O2-1"), "tools": [1],
         "done": {"reading": ["O2-1"]}, "in": ["SO_in1", "SO_in2"], "target": {"ctrl": "O2-1"}},
        {"id": "vent", "text": t("氧太高，激光一碰就闪燃：软管接 G-OX 抽到 5 kPa 以下（5）", "OXYGEN-RICH: A LASER FLASHES IT. HOSE ON G-OX, UNDER 5 kPa (5)"), "tools": [1, 5],
         "done": {"P": ["OX", "<", 5.0]}, "target": {"ctrl": "G-OX"}, "warp": True, "out": ["SO_safe_t"]},
        {"id": "lid", "text": t("拆下顶板 OX-T 的螺栓（4），推到一边", "WRENCH (4): UNBOLT THE LID OX-T, PUSH IT CLEAR"), "tools": [3, 4], "context": True,
         "done": {"free": "OX-T"}, "target": {"piece": "OX-T"}},
        {"id": "lamp", "text": t("拆下补光灯 GL-1（4）", "WRENCH (4): FREE THE GROW LAMP GL-1"), "tools": [3, 4], "context": True,
         "done": {"free": "GL-1"}, "target": {"piece": "GL-1"}},
        {"id": "deliver", "text": t("补光灯完整送进设备回收口", "THE LAMP, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["GL-1", "any"]}, "out": ["SO_done"], "target": {"zone": "equip"}},
    ]},
    {"id": "SP_A2", "mode": "lockstep", "title": t("复合材料：别切，拧下来", "COMPOSITE: DON'T CUT IT, UNBOLT IT"), "done_flag": "SP_A2_COMPLETE",
     "guard": {"pieces": ["HC-1"], "until": {"P": ["AV", "<", 5.0]}, "lock": ["SM_lock_t", "SM_lock_l"],
               "accident": ["composite_fumes", "blowout"], "reset": ["HC-1", "AV-C"], "remod": ["composite"], "say": "SM_bad",
               "restore": {"gas": ["AV"], "hoses": ["G-AV"], "readings": ["FM-1"]}},
     "steps": [
        {"id": "fume", "text": t("测量（1）：读航电舱的烟雾 FM-1", "MEASURE (1): SMOKE IN THE AVIONICS BAY, FM-1"), "tools": [1],
         "done": {"reading": ["FM-1"]}, "in": ["SM_in1", "SM_in2"], "target": {"ctrl": "FM-1"}},
        {"id": "vent", "text": t("舱里有气：切碳纤维会冒毒烟。先接 G-AV 抽成真空（5）", "AIR INSIDE: CUT FIBRE SMOKES. HOSE G-AV DOWN TO VACUUM (5)"), "tools": [1, 5],
         "done": {"P": ["AV", "<", 5.0]}, "target": {"ctrl": "G-AV"}, "warp": True, "out": ["SM_safe_t"]},
        {"id": "unbolt", "text": t("拧下复合材料顶板 HC-1 的四颗螺栓（4），推到一边", "WRENCH (4): UNBOLT THE COMPOSITE LID HC-1, PUSH IT CLEAR"), "tools": [3, 4], "context": True,
         "done": {"free": "HC-1"}, "target": {"piece": "HC-1"}},
        {"id": "console", "text": t("拆下舱里的航电台 AV-C（4）", "WRENCH (4): FREE THE AVIONICS CONSOLE AV-C"), "tools": [3, 4], "context": True,
         "done": {"free": "AV-C"}, "target": {"piece": "AV-C"}},
        {"id": "deliver", "text": t("没被烟熏过的航电台完整送进设备回收口", "THE CONSOLE, UNSMOKED AND WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["AV-C", "any"]}, "out": ["SM_done"], "target": {"zone": "equip"}},
    ]},
    {"id": "SP_A3", "mode": "lockstep", "title": t("炉芯：停机不等于冷却", "THE CORE: STOPPED ISN'T COLD"), "done_flag": "SP_A3_COMPLETE",
     "guard": {"pieces": ["CORE"], "until": {"mod": ["furnace", "core_temp", "<", 150.0]}, "lock": ["SH_lock_t", "SH_lock_l"],
               "accident": ["core_cracked"], "reset": ["CORE"], "remod": ["furnace"], "say": "SH_bad",
               "restore": {"hoses": ["PL"], "readings": ["CT-1"]}},
     "steps": [
        {"id": "temp", "text": t("测量（1）：读炉芯温度 CT-1", "MEASURE (1): CORE TEMPERATURE CT-1"), "tools": [1],
         "done": {"reading": ["CT-1"]}, "in": ["SH_in1", "SH_in2"], "target": {"ctrl": "CT-1"}},
        {"id": "cool", "text": t("换热泵有电、回路满着：等它降到 150 °C 以下（按住 = 加速）", "PUMP POWERED, LOOP FULL: WAIT UNDER 150 °C (HOLD = TO SPEED UP)"), "tools": [1],
         "done": {"mod": ["furnace", "core_temp", "<", 150.0]}, "warp": True, "out": ["SH_safe_t"]},
        {"id": "drain", "text": t("冷透了，现在才放冷却液：软管接 PL（5）", "COLD THROUGH: ONLY NOW DRAIN THE LOOP, HOSE ON PL (5)"), "tools": [1, 5],
         "done": {"fluid": ["loop", "<", 0.01]}, "target": {"ctrl": "PL"}, "warp": True},
        {"id": "free", "text": t("拆下炉芯 CORE 的螺栓和管子（4）", "WRENCH (4): FREE THE CORE"), "tools": [3, 4], "context": True,
         "done": {"free": "CORE"}, "target": {"piece": "CORE"}},
        {"id": "deliver", "text": t("炉芯完整送进设备回收口", "THE CORE, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["CORE", "any"]}, "out": ["SH_done"], "target": {"zone": "equip"}},
    ]},
], {
    "SO_lock_t": ("训练安全联锁启动：舱内仍是富氧空气。", "TRAINING INTERLOCK: THE BAY STILL HOLDS OXYGEN-RICH AIR."),
    "SO_safe_t": ("舱压已降到安全值。", "BAY PRESSURE BELOW SAFE."),
    "SM_lock_t": ("训练安全联锁启动：舱内仍有空气。", "TRAINING INTERLOCK: THERE IS STILL AIR IN THE BAY."),
    "SM_safe_t": ("舱压已降到安全值。", "BAY PRESSURE BELOW SAFE."),
    "SH_lock_t": ("训练安全联锁启动：炉芯仍然高温。", "TRAINING INTERLOCK: THE CORE IS STILL HOT."),
    "SH_safe_t": ("炉芯已冷却到安全温度。", "CORE BELOW SAFE TEMPERATURE."),
})

# ---------------------------------------------------------------- loads and motion
course("load", [
    {"id": "SP_L1", "mode": "lockstep", "title": t("预紧的折叠臂：能量、锁、结构", "A PRELOADED ARM: ENERGY, LOCKS, STRUCTURE"), "done_flag": "SP_L1_COMPLETE",
     "guard": {"pieces": ["ARM-1"], "until": {"P": ["ACC", "<", 30.0]}, "lock": ["SL_lock_t", "SL_lock_l"],
               "accident": ["preload"], "reset": ["ARM-1"], "remod": ["mech"], "say": "SL_bad",
               "restore": {"gas": ["ACC"], "hoses": ["G-ACC"], "readings": ["TN-1", "G-ACC"]}},
     "steps": [
        {"id": "tension", "text": t("测量（1）：读枢轴张力 TN-1", "MEASURE (1): PIVOT TENSION TN-1"), "tools": [1],
         "done": {"reading": ["TN-1"]}, "in": ["SL_in1", "SL_in2"], "target": {"ctrl": "TN-1"}},
        {"id": "bleed", "text": t("① 能量：软管接 G-ACC，蓄能器泄到 30 kPa 以下（5）", "① ENERGY: HOSE ON G-ACC, THE ACCUMULATOR BELOW 30 kPa (5)"), "tools": [1, 5],
         "done": {"P": ["ACC", "<", 30.0]}, "target": {"ctrl": "G-ACC"}, "warp": True},
        {"id": "pins", "text": t("② 锁：拔掉两根锁销 PIN-1、PIN-2（4）", "② LOCKS: PULL BOTH PINS, PIN-1 AND PIN-2 (4)"), "tools": [1, 4], "context": True,
         "done": {"all": [{"joint_gone": "PIN-1"}, {"joint_gone": "PIN-2"}]}, "out": ["SL_safe_t"], "target": {"piece": "ARM-1"}},
        {"id": "pivot", "text": t("③ 结构：最后拆枢轴 PIV-1（4）", "③ STRUCTURE: THE PIVOT PIV-1 LAST (4)"), "tools": [1, 3, 4], "context": True,
         "done": {"joint_gone": "PIV-1"}, "target": {"piece": "ARM-1"}},
        {"id": "deliver", "text": t("折叠臂完整送进设备回收口", "THE ARM, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["ARM-1", "any"]}, "out": ["SL_done"], "target": {"zone": "equip"}},
    ]},
    {"id": "SP_L2", "mode": "lockstep", "title": t("锁轨货物：开门、解锁、让它滑出来", "RAIL-LOCKED CARGO: GATE, LOCK, LET IT RUN OUT"), "done_flag": "SP_L2_COMPLETE",
     "guard": {"pieces": ["RL-1", "RP-1", "RP-2"], "until": {"switch": ["LK-1", False]}, "lock": ["SG_lock_t", "SG_lock_l"],
               "accident": ["rail_cut"], "reset": ["RL-1", "BOX-1"], "remod": ["rails"], "say": "SG_bad",
               "restore": {"ctrls": ["LK-1"]}},
     "steps": [
        {"id": "gate", "text": t("① 先打开轨道尽头的挡门 GATE（4，要有电）", "① OPEN THE GATE AT THE RAIL'S END FIRST: GATE (4, NEEDS POWER)"), "tools": [1, 4], "context": True,
         "done": {"door": ["GATE", True]}, "in": ["SG_in1", "SG_in2"], "target": {"ctrl": "GATE"}},
        {"id": "release", "text": t("② 松开轨道锁 LK-1（4）：货箱沿轨道自己滑出", "② RELEASE THE RAIL LOCK LK-1 (4): THE CRATE RUNS OUT BY ITSELF"), "tools": [1, 4], "context": True,
         "done": {"switch": ["LK-1", False]}, "target": {"ctrl": "LK-1"}},
        {"id": "catch", "text": t("接住货箱，完整送进设备回收口", "CATCH THE CRATE, DELIVER IT WHOLE TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["BOX-1", "any"]}, "out": ["SG_done"], "target": {"piece": "BOX-1"}},
    ]},
], {
    "SL_lock_t": ("训练安全联锁启动：蓄能器仍有压力。", "TRAINING INTERLOCK: THE ACCUMULATOR IS STILL CHARGED."),
    "SL_safe_t": ("预紧已解除。", "PRELOAD RELEASED."),
    "SG_lock_t": ("训练安全联锁启动：轨道上仍锁着货物。", "TRAINING INTERLOCK: CARGO STILL LOCKED ON THE RAIL."),
})

# ---------------------------------------------------------------- precision parts
course("precise", [
    {"id": "SP_P1", "mode": "lockstep", "title": t("主镜：防尘罩、促动器锁、外圈先拆", "THE MIRROR: COVER, LOCKS, OUTER RING FIRST"), "done_flag": "SP_P1_COMPLETE",
     "guard": {"pieces": ["PM-1", "PM-2", "INS", "IP"], "until": {"mod": ["optics", "cover_down", ">", 0.5]}, "lock": ["SP_lock_t", "SP_lock_l"],
               "accident": ["mirror_dust", "mirror_drop", "mirror_unsupported"], "reset": ["PM-1", "PM-2", "INS"], "remod": ["optics"], "say": "SP_bad",
               "restore": {"ctrls": ["CVR", "LK-1", "LK-2"], "readings": ["OPT"]}},
     "steps": [
        {"id": "opt", "text": t("测量（1）：读主镜反射率 OPT", "MEASURE (1): THE MIRROR'S REFLECTANCE OPT"), "tools": [1],
         "done": {"reading": ["OPT"]}, "in": ["SPM_in1", "SPM_in2"], "target": {"ctrl": "OPT"}},
        {"id": "cover", "text": t("① 放下防尘罩：CVR（4），等它完全落下", "① RUN THE DUST COVER DOWN: CVR (4), ALL THE WAY"), "tools": [1, 4], "context": True,
         "done": {"mod": ["optics", "cover_down", ">", 0.5]}, "target": {"ctrl": "CVR"}},
        {"id": "cut", "text": t("② 激光（2）切开仪器 INS 和立柱之间的焊缝", "② LASER (2): CUT THE WELDS BETWEEN INSTRUMENT INS AND ITS POST"), "tools": [2, 3, 4],
         "done": {"free": "INS"}, "target": {"piece": "INS"}},
        {"id": "ins", "text": t("仪器完整送进设备回收口", "THE INSTRUMENT, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["INS", "any"]}, "target": {"zone": "equip"}},
        {"id": "locks", "text": t("③ 锁住两圈促动器 LK-1、LK-2（4，控制柜要有电）", "③ LOCK BOTH RINGS: LK-1, LK-2 (4, CABINET POWERED)"), "tools": [1, 4], "context": True,
         "done": {"all": [{"switch": ["LK-1", True]}, {"switch": ["LK-2", True]}]}, "target": {"ctrl": "LK-1"}},
        {"id": "outer", "text": t("④ 先拆外圈镜片 PM-2（4）", "④ THE OUTER SEGMENT PM-2 FIRST (4)"), "tools": [3, 4], "context": True,
         "done": {"free": "PM-2"}, "target": {"piece": "PM-2"}},
        {"id": "outer_in", "text": t("PM-2 送进设备回收口", "PM-2 TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["PM-2", "any"]}, "target": {"zone": "equip"}, "exit": [1.8, 0.0]},
        {"id": "inner", "text": t("⑤ 再拆内圈 PM-1（4）", "⑤ THEN THE INNER PM-1 (4)"), "tools": [3, 4], "context": True,
         "done": {"free": "PM-1"}, "target": {"piece": "PM-1"}},
        {"id": "inner_in", "text": t("PM-1 送进设备回收口", "PM-1 TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["PM-1", "any"]}, "out": ["SPM_done"], "target": {"zone": "equip"}, "exit": [0.0, -2.0]},
    ]},
    {"id": "SP_P2", "mode": "lockstep", "title": t("承压玻璃：先泄压，再拧压条", "GLASS UNDER PRESSURE: VENT, THEN THE STRIPS"), "done_flag": "SP_P2_COMPLETE",
     "guard": {"pieces": ["OBS-1"], "until": {"P": ["O", "<", 20.0]}, "lock": ["SW_lock_t", "SW_lock_l"],
               "accident": ["glass_blown"], "reset": ["OBS-1"], "remod": ["liner"], "say": "SW_bad",
               "restore": {"gas": ["O"], "hoses": ["G-O"], "readings": ["G-O"]}},
     "steps": [
        {"id": "kpa", "text": t("测量（1）：读观景舱舱压 G-O", "MEASURE (1): THE HALL'S PRESSURE AT G-O"), "tools": [1],
         "done": {"reading": ["G-O"]}, "in": ["SW_in1", "SW_in2"], "target": {"ctrl": "G-O"}},
        {"id": "vent", "text": t("① 软管接 G-O，抽到 5 kPa 以下（5）", "① HOSE ON G-O, BELOW 5 kPa (5)"), "tools": [1, 5],
         "done": {"P": ["O", "<", 5.0]}, "target": {"ctrl": "G-O"}, "warp": True, "out": ["SW_safe_t"]},
        {"id": "strips", "text": t("② 拧下玻璃 OBS-1 的压条螺栓（4）", "② UNBOLT THE CLAMPING STRIPS OF PANE OBS-1 (4)"), "tools": [3, 4], "context": True,
         "done": {"free": "OBS-1"}, "target": {"piece": "OBS-1"}},
        {"id": "deliver", "text": t("整块玻璃送进设备回收口", "THE PANE, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["OBS-1", "any"]}, "out": ["SW_done"], "target": {"zone": "equip"}},
    ]},
], {
    "SP_lock_t": ("训练安全联锁启动：防尘罩未放下。", "TRAINING INTERLOCK: THE DUST COVER IS NOT DOWN."),
    "SW_lock_t": ("训练安全联锁启动：玻璃背后仍有压力。", "TRAINING INTERLOCK: THERE IS STILL PRESSURE BEHIND THE GLASS."),
    "SW_safe_t": ("舱压已降到安全值。", "HALL PRESSURE BELOW SAFE."),
})

# ---------------------------------------------------------------- isolation and extraction
course("isolate", [
    {"id": "SP_I1", "mode": "lockstep", "title": t("船中船：整艘取出", "A SHIP IN A SHIP: OUT WHOLE"), "done_flag": "SP_I1_COMPLETE",
     "guard": {"pieces": ["SS-H1", "SS-H2", "SS-N", "SS-T"], "until": {"mod": ["nested", "is_out", ">", 0.5]}, "lock": ["SN_lock_t", "SN_lock_l"],
               "accident": ["nested_lurch", "nested_cut"], "reset": ["SS-H1", "SS-H2", "SS-N", "SS-T", "SS-BAT", "SS-ENG"], "remod": ["nested"], "say": "SN_bad",
               "restore": {"ctrls": ["SK", "CL-1", "CL-2", "WINCH"]}},
     "steps": [
        {"id": "battery", "text": t("① 先处理小船自己的危险：断开它的电池 SK（4）", "① ITS OWN DANGERS FIRST: ITS BATTERY SK OFF (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["SK", False]}, "in": ["SN_in1", "SN_in2"], "target": {"ctrl": "SK"}},
        {"id": "stern", "text": t("② 托架锁从船尾松起：CL-1（4）", "② THE CRADLE LOCKS FROM THE STERN: CL-1 (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["CL-1", False]}, "target": {"ctrl": "CL-1"}},
        {"id": "bow", "text": t("③ 再松船首的 CL-2（4）", "③ THEN THE BOW'S CL-2 (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["CL-2", False]}, "target": {"ctrl": "CL-2"}},
        {"id": "door", "text": t("④ 打开首门 BOW（4）", "④ OPEN THE BOW DOOR BOW (4)"), "tools": [1, 4], "context": True,
         "done": {"door": ["BOW", True]}, "target": {"ctrl": "BOW"}},
        {"id": "winch", "text": t("⑤ 开绞车 WINCH：整艘拖出（一块外壳都别切）", "⑤ THE WINCH: OUT IT GOES, WHOLE (CUT NONE OF ITS HULL)"), "tools": [1, 4], "context": True,
         "done": {"mod": ["nested", "is_out", ">", 0.5]}, "out": ["SN_done"], "target": {"ctrl": "WINCH"}},
    ]},
    {"id": "SP_I2", "mode": "lockstep", "title": t("库门：两路电都断，才扳释放杆", "THE VAULT: BOTH SUPPLIES DEAD, THEN THE LEVER"), "done_flag": "SP_I2_COMPLETE",
     "guard": {"pieces": ["LS-1", "VD-1", "SDB-1"], "until": {"all": [{"switch": ["K-B", False]}, {"switch": ["K-LB", False]}]}, "lock": ["SV_lock_t", "SV_lock_l"],
               "accident": ["arc"], "reset": ["LS-1"], "say": "SV_bad",
               "restore": {"power": True, "ctrls": ["K-B", "K-LB", "MR-1"], "readings": ["E-L", "E-B"]}},
     "steps": [
        {"id": "test", "text": t("测量（1）：门锁电磁铁的验电点 E-L", "MEASURE (1): THE LOCK SOLENOID'S TEST POINT E-L"), "tools": [1],
         "done": {"reading": ["E-L"]}, "in": ["SV_in1", "SV_in2"], "target": {"ctrl": "E-L"}},
        {"id": "main", "text": t("① 断开主开关 K-B（4）", "① THE MAIN SWITCH K-B OFF (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["K-B", False]}, "target": {"ctrl": "K-B"}},
        {"id": "retest", "text": t("再测 E-L：还带电？", "MEASURE E-L AGAIN: STILL LIVE?"), "tools": [1],
         "done": {"reading_after": ["E-L", "main"]}, "out": ["SV_backfeed_t"], "target": {"ctrl": "E-L"}},
        {"id": "backup", "text": t("② 备用电源在倒灌：断开门锁备用电源 K-LB（4）", "② THE BACKUP FEEDS IT: THE LOCK BACKUP K-LB OFF (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["K-LB", False]}, "target": {"ctrl": "K-LB"}},
        {"id": "verify", "text": t("再测 E-L，确认 0 V", "MEASURE E-L: CONFIRM 0 V"), "tools": [1],
         "done": {"reading": ["E-L", "<", 1.0]}, "target": {"ctrl": "E-L"}},
        {"id": "lever", "text": t("③ 扳释放杆 MR-1（4）", "③ THROW THE RELEASE LEVER MR-1 (4)"), "tools": [1, 4], "context": True,
         "done": {"switch": ["MR-1", True]}, "target": {"ctrl": "MR-1"}},
        {"id": "open", "text": t("④ 打开库门 VD-1（4，不需要电）", "④ OPEN THE VAULT DOOR VD-1 (4, NO POWER NEEDED)"), "tools": [1, 4], "context": True,
         "done": {"door": ["VD-1", True]}, "target": {"ctrl": "VD-1"}},
        {"id": "box", "text": t("拆下保管箱 SDB-1（4）", "WRENCH (4): FREE THE DEPOSIT BOXES SDB-1"), "tools": [3, 4], "context": True,
         "done": {"free": "SDB-1"}, "target": {"piece": "SDB-1"}},
        {"id": "deliver", "text": t("保管箱整件送进设备回收口", "THE BOXES, WHOLE, TO THE EQUIPMENT BAY"), "tools": [3, 4], "context": True,
         "done": {"recovered": ["SDB-1", "any"]}, "out": ["SV_done"], "target": {"zone": "equip"}, "exit": [2.8, 0.0]},
    ]},
], {
    "SN_lock_t": ("训练安全联锁启动：小船尚未取出。", "TRAINING INTERLOCK: THE SMALL SHIP IS NOT OUT."),
    "SV_lock_t": ("训练安全联锁启动：门锁仍有供电。", "TRAINING INTERLOCK: THE LOCK STILL HAS A SUPPLY."),
    "SV_backfeed_t": ("检测到备用供电路径：门锁备用电源。", "BACKUP SUPPLY PATH DETECTED: THE LOCK'S OWN BACKUP."),
})
