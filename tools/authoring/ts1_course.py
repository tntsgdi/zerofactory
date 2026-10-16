"""The training course on TS-1 ("FIRST SHIFT"), as data for scripts/tutorial.gd.
python tools/authoring/ts1_course.py  ->  ships/ts1_course.json

lines     id -> {who: liang|term, zh, en}       radio and terminal lines (each <= ~12 s)
lessons   [{id, mode: lockstep|goal, title, steps, guard?, reset?, done_flag}]
steps     [{id, text, tools, target, done, in, out, hint, auto}]
          done is one predicate (see tutorial.gd _check) or {"all": [...]}
"""
import json, os

L = {}


def line(id, who, zh, en):
    L[id] = {"who": who, "zh": zh, "en": en}
    return id


# ---------------------------------------------------------------- TUT_00 arrival
line("T00_1", "liang", "听得见吗？……行，通信正常。", "Can you hear me? ...Right, comms are good.")
line("T00_2", "liang", "欢迎来到 BERTH 07。今天第一天上班，先别碰停在外面的那些大船。", "Welcome to Berth 07. First day on the job — leave the big hulls outside alone for now.")
line("T00_3", "liang", "中间这个是 TS-1，报废穿梭机上切下来的训练舱段，正好拿来练手。", "That one in the middle is TS-1, a training section cut off a scrapped shuttle. Good for practice.")
line("T00_4", "term", "远程操作权限已确认。训练项目 TS-1 已载入。", "REMOTE OPERATION AUTHORISED. TRAINING ITEM TS-1 LOADED.")
line("T00_5", "liang", "今天只有一条规矩：不确定的东西，先查清楚再动。", "One rule today: if you're not sure, check before you touch it.")

# ---------------------------------------------------------------- TUT_01 look first
line("T01_in", "liang", "先把无人机飞起来。穿过那几个光环。", "Get the drone moving first. Fly through those rings.")
line("T01_dash", "liang", "长的那个，按住 Shift 冲过去。", "The long one — hold Shift and dash through.")
line("T01_stop", "liang", "进框，按 Space 停稳。", "Into the box, Space to stop dead.")
line("T01_f", "liang", "F 是飞行稳定。关掉试试，再开回来。", "F is flight assist. Switch it off, feel it, switch it back on.")
line("T01_find", "liang", "看到左侧那块检修盖了吗？找找它的编号。", "See the service cover on the left side? Find its number.")
line("T01_found", "term", "设备 P-001 已识别。", "ITEM P-001 IDENTIFIED.")
line("T01_tab", "liang", "现在打开工程图。", "Now open the drawing.")
line("T01_bp1", "liang", "图纸是设计的时候画的，船是后来撞坏的。两边不一定对得上。", "The drawing was made at design time. The ship got wrecked later. They won't always agree.")
line("T01_bp2", "liang", "先用它找东西，至于东西现在是什么样，你自己检查。", "Use it to find things. What state they're in now — you check that yourself.")
line("T01_h1", "liang", "面板就在舱段左侧。先把摄像头拉近。", "The panel is on the left end of the section. Zoom in first.")

# ---------------------------------------------------------------- TUT_02 first scrap
line("T02_in1", "liang", "这块盖板已经检查过了，没有压力，也没接电。", "That cover's been checked. No pressure behind it, no power.")
line("T02_in2", "liang", "任务很简单，把它完整拆下来，送进回收口。别直接拿切割器烧。四颗螺栓。", "Simple job: take it off in one piece and into a mouth. Don't burn it off. Four bolts.")
line("T02_last", "liang", "先等等。最后一个螺栓拆掉，这块板就没东西固定了。用抓钩把它稳住。", "Hold on. Take the last bolt out and nothing holds that plate. Steady it with the grapple first.")
line("T02_drift", "liang", "看见没有？这地方没有地板替你接东西。下次先固定，再松最后一个连接。", "See that? There's no floor out here to catch things. Secure it first, then the last fixing.")
line("T02_done_t", "term", "金属结构回收完成。回收重量 0.18 t。资产价值 120 信用点。", "METAL RECOVERED. 0.18 t. VALUE 120 CR.")
line("T02_done_l", "liang", "第一笔收入，够买几杯咖啡。先别急着发财，接下来还有正事。", "First earnings — a few coffees' worth. Don't get rich yet, the real work's next.")
line("T02_h1", "liang", "四个角上那几颗螺栓，用维护工具一颗一颗拧。", "The bolts down its edge — wrench them out one by one.")

# ---------------------------------------------------------------- TUT_03 zero isn't safe
line("T03_in", "liang", "这块外壳后面是密封舱。想拆可以，先确认里面还有没有气。", "Behind that shell plate is a sealed bay. Fine to take it off — once you know there's no gas in there.")
line("T03_ask", "liang", "读数出来了。你觉得现在能拆吗？", "There's your reading. Safe to take it off now?")
line("T03_A", "liang", "零倒是零。可它测的是哪儿？先把工程图打开。", "It's zero, sure. But zero where? Open the drawing.")
line("T03_B", "liang", "对，先确定你测的是哪一段。", "Right. First work out which bit you actually measured.")
line("T03_found", "liang", "阀门关着，压力表根本没连到舱室。仪器没坏。是你刚才不知道它测的是什么。", "The valve's shut — the gauge never saw the bay. The meter's fine. You just didn't know what it was measuring.")
line("T03_real", "liang", "这回才是舱里的压力。要是刚才直接拆开，里面的气就全跑到船坞里了。", "That's the bay. Open it a minute ago and all that gas goes into the berth.")
line("T03_wait", "liang", "这回不用着急，等泵把气收完。真空里工作，最没用的就是催机器。", "No hurry now. Let the pump take it. Out here, rushing machines gets you nothing.")
line("T03_empty_t", "term", "舱室压力进入训练允许范围。气体回收完成。", "BAY PRESSURE WITHIN TRAINING LIMIT. GAS RECOVERED.")
line("T03_empty_l", "liang", "好。现在可以处理这块外壳了。", "Good. Now the plate.")
line("T03_open", "liang", "这就是拆船。你不知道里面是什么，就得一点点把它查清楚。", "That's salvage. You don't know what's inside, so you find out, one thing at a time.")
line("T03_lock_t", "term", "训练安全联锁启动：目标舱室状态未确认。", "TRAINING INTERLOCK: TARGET BAY NOT VERIFIED.")
line("T03_lock_l", "liang", "真船可不会替你拦这一下。", "A real ship won't stop you like that.")
line("T03_boom", "liang", "……还好不是人。重置一下，再来。", "...Good thing nobody was in there. Resetting. Again.")
line("T03_h1", "liang", "看看测压口和舱室之间，管子上还有什么。", "Look at what sits on the line between the port and the bay.")

# ---------------------------------------------------------------- TUT_04 off isn't dead
line("T04_in1", "liang", "现在要回收这个供电模块。", "Next: recover the power module.")
line("T04_in2", "liang", "控制台说主电源关了。不过旁边那盏灯还亮着。你先查查。", "The panel says main power's off. That lamp next to it says otherwise. Check.")
line("T04_backup_t", "term", "检测到备用供电路径。", "BACKUP SUPPLY PATH DETECTED.")
line("T04_backup_l", "liang", "明白了吧？主电源停了，备用电池还在供电。船上的电源从来不保证只有一个。", "See? Main's off, the backup battery is still feeding it. A ship never promises just one source.")
line("T04_cap", "liang", "还有电容。先让设备完成受控放电和状态验证。别急着拆。", "And there's the capacitor. Bleed it through the plug and verify. Don't rush it.")
line("T04_ok_t", "term", "目标电气区域验证完成。允许进行指定模块拆卸。", "ELECTRICAL ZONE VERIFIED. MODULE REMOVAL PERMITTED.")
line("T04_done", "liang", "这就对了。要是把完整模块直接烧成废铁，老板估计比电容炸了还心疼。", "That's it. Burn a whole module down to scrap and the boss would cry harder than if the cap blew.")
line("T04_lock_t", "term", "训练安全联锁启动：目标电气区域未验证。", "TRAINING INTERLOCK: ELECTRICAL ZONE NOT VERIFIED.")
line("T04_arc", "liang", "那一下，在真船上能要命。重置。", "On a real ship that one kills. Resetting.")
line("T04_h1", "liang", "灯还亮着，电是从哪儿来的？图纸的电路层里找找。", "The lamp's still lit — where's that power coming from? Look at the circuit in the drawing.")

# ---------------------------------------------------------------- TUT_05 missed a pipe
line("T05_in1", "liang", "那边还有台冷却泵。这东西能卖点钱。你把它完整取下来。", "There's a coolant pump over there. Worth something. Get it out whole.")
line("T05_in2", "liang", "不用我再告诉你先查什么了吧？", "I don't need to tell you what to check first, do I?")
line("T05_pull", "liang", "别拽了。看一眼，下面还有东西连着呢。", "Stop pulling. Look — something's still attached.")
line("T05_cut", "liang", "也行，至少能卖废金属。不过下次可以试着把整台拿下来，价钱差得不少。", "Fine, it'll sell as scrap. Next time try getting it out whole — big difference in price.")
line("T05_done_l", "liang", "不错。这才叫拆设备，不是拆垃圾。", "Nice. That's salvaging equipment, not shovelling junk.")
line("T05_h3", "liang", "还有一个连接没解。", "One connection is still on.")

# ---------------------------------------------------------------- TUT_06 heavy things
line("T06_in", "liang", "最后剩这些骨架。拆完训练就结束。", "Just the frame left. Clear it and training's done.")
line("T06_heavy1", "liang", "超重了。你可以去仓库买台更大的设备，前提是老板愿意出钱。", "Too heavy. You could buy a bigger grapple — if the boss pays for it.")
line("T06_heavy2", "liang", "今天就用现有的工具。看看能不能把它分开。", "Today you use what you've got. See if it splits.")
line("T06_boom", "liang", "残液进炉子，就是这个下场。重置。", "Residue in the furnace — that's what happens. Resetting.")
line("T06_done_t", "term", "TS-1 拆解任务完成。训练舱段剩余可回收结构：0。", "TS-1 DISMANTLED. RECOVERABLE STRUCTURE REMAINING: 0.")
line("T06_done_l", "liang", "行，至少你没把船坞一起拆了。培训先到这儿。", "Well, you didn't take the berth apart with it. That's training.")
line("T06_h3", "liang", "看看图纸，那根梁是两段拼起来的。", "Check the drawing — that beam is two pieces joined together.")
line("T_exam_offer", "liang", "接下来有个小考核。想试就试，不想试也能直接接第一份合同。", "There's a short test next. Take it if you like — or go straight to your first contract.")

# ---------------------------------------------------------------- lessons
def t(zh, en):
    return {"zh": zh, "en": en}


LESSONS = [
    {"id": "TUT_00", "mode": "lockstep", "title": t("到岗", "ARRIVAL"), "done_flag": "TUT_00_COMPLETE", "steps": [
        {"id": "comms", "text": t("等待接通", "COMMS CHECK"), "tools": [], "done": {"lines_done": True},
         "in": ["T00_1", "T00_2", "T00_3", "T00_4", "T00_5"]},
    ]},
    {"id": "TUT_01", "mode": "lockstep", "title": t("先学会看", "LOOK FIRST"), "done_flag": "TUT_01_COMPLETE", "steps": [
        {"id": "rings", "text": t("穿过 3 个光环", "FLY THROUGH 3 RINGS"), "tools": [], "done": {"rings": 3}, "in": ["T01_in"], "target": {"ring": 0}},
        {"id": "dash", "text": t("按住 Shift 冲过长光环", "HOLD SHIFT THROUGH THE LONG RING"), "tools": [], "done": {"dash_ring": True}, "in": ["T01_dash"], "target": {"ring": 3}},
        {"id": "stop", "text": t("进框，按 Space 停稳", "INTO THE BOX, SPACE TO STOP"), "tools": [], "done": {"stop_box": True}, "in": ["T01_stop"], "target": {"box": True}},
        {"id": "assist", "text": t("按 F 关掉飞行稳定，再打开", "F: ASSIST OFF, THEN ON"), "tools": [], "done": {"assist_cycle": True}, "in": ["T01_f"]},
        {"id": "find", "text": t("用测量（1）点选检修盖 P-001", "MEASURE (1): SELECT COVER P-001"), "tools": [1], "done": {"inspected": "P-001"},
         "in": ["T01_find"], "out": ["T01_found"], "target": {"piece": "P-001"}, "hint": "T01_h1", "auto": [13.9, -0.6]},
        {"id": "tab", "text": t("按 Tab 打开工程图", "TAB: OPEN THE DRAWING"), "tools": [1], "done": {"blueprint": True},
         "in": ["T01_tab"], "out": ["T01_bp1", "T01_bp2"]},
    ]},
    {"id": "TUT_02", "mode": "lockstep", "title": t("你的第一块废铁", "FIRST SCRAP"), "done_flag": "TUT_02_COMPLETE", "steps": [
        {"id": "unbolt", "text": t("用维护工具（4）拧下 P-001 的螺栓", "WRENCH (4): UNBOLT P-001"), "tools": [4], "done": {"joints_left": ["P-001", "<=", 1]},
         "in": ["T02_in1", "T02_in2"], "target": {"piece": "P-001"}, "hint": "T02_h1", "auto": [13.9, -0.4]},
        {"id": "hold", "text": t("先用磁力抓钩（3）稳住盖板", "GRAPPLE (3): STEADY THE COVER"), "tools": [3, 4], "done": {"any": [{"held": "P-001"}, {"free": "P-001"}]},
         "in": ["T02_last"], "target": {"piece": "P-001"}},
        {"id": "last", "text": t("拧下最后一颗螺栓（抓钩不放）", "UNBOLT THE LAST ONE (KEEP HOLD)"), "tools": [3, 4], "done": {"free": "P-001"}, "target": {"piece": "P-001"}},
        {"id": "furnace", "text": t("拖进金属熔炉", "HAUL IT INTO THE FURNACE"), "tools": [3, 4], "done": {"recovered": ["P-001", "metal"]},
         "out": ["T02_done_t", "T02_done_l"], "target": {"zone": "metal"}},
    ]},
    {"id": "TUT_03", "mode": "lockstep", "title": t("零不代表安全", "ZERO ISN'T SAFE"), "done_flag": "TUT_03_COMPLETE",
     "guard": {"pieces": ["P-002"], "until": {"P": ["TC", "<", 5.0]}, "lock": ["T03_lock_t", "T03_lock_l"],
               "accident": ["blowout"], "reset": ["P-002"], "say": "T03_boom",
               "restore": {"gas": ["TC", "SC-T"], "ctrls": ["V-02"], "hoses": ["GAS-T1", "PT-02"], "readings": ["PT-02"]}},
     "steps": [
        {"id": "measure", "text": t("用测量（1）测 PT-02", "MEASURE (1): PT-02"), "tools": [1], "done": {"reading": ["PT-02"]},
         "in": ["T03_in"], "target": {"ctrl": "PT-02"}, "auto": [15.5, -3.6]},
        {"id": "ask", "text": t("现在能拆吗？", "SAFE TO OPEN?"), "tools": [], "done": {"choice": True}, "in": ["T03_ask"],
         "choice": {"a": t("可以，仪器显示零压力", "YES — THE METER SAYS ZERO"), "b": t("还不能确定，要检查测量通路", "NOT YET — CHECK WHAT IT MEASURED"), "a_line": "T03_A", "b_line": "T03_B"}},
        {"id": "trace", "text": t("按 Tab，沿 PT-02 的管路找", "TAB: TRACE PT-02'S LINE"), "tools": [1], "done": {"blueprint": True}, "out": ["T03_found"], "hint": "T03_h1"},
        {"id": "valve", "text": t("用维护工具（4）打开 V-02", "WRENCH (4): OPEN V-02"), "tools": [4], "done": {"switch": ["V-02", True]}, "target": {"ctrl": "V-02"}, "auto": [15.8, -3.6]},
        {"id": "remeasure", "text": t("重新测量 PT-02", "MEASURE PT-02 AGAIN"), "tools": [1], "done": {"reading": ["PT-02", ">", 90.0]},
         "out": ["T03_real"], "flag": "TUT_03_VALID_MEASUREMENT", "target": {"ctrl": "PT-02"}},
        {"id": "hose", "text": t("气液回收（5）：软管接 GAS-T1", "HOSE (5): CONNECT GAS-T1"), "tools": [5], "done": {"hose": "GAS-T1"}, "out": ["T03_wait"], "target": {"ctrl": "GAS-T1"}, "auto": [18.3, -3.6]},
        {"id": "wait", "text": t("等 TC-1 降到 5 kPa 以下（按住 = 加速）", "WAIT: TC-1 BELOW 5 kPa (HOLD = TO SPEED UP)"), "tools": [1, 5], "done": {"P": ["TC", "<", 5.0]},
         "out": ["T03_empty_t", "T03_empty_l"], "warp": True},
        {"id": "plate", "text": t("拆下 P-002：螺栓（4）＋抓钩（3）", "TAKE OFF P-002: BOLTS (4) + GRAPPLE (3)"), "tools": [3, 4], "done": {"free": "P-002"}, "out": ["T03_open"], "target": {"piece": "P-002"}},
        {"id": "scrap", "text": t("送进金属熔炉", "INTO THE FURNACE"), "tools": [3, 4], "done": {"recovered": ["P-002", "any"]}, "target": {"zone": "metal"}},
    ]},
    {"id": "TUT_04", "mode": "lockstep", "title": t("关机不等于断电", "OFF ISN'T DEAD"), "done_flag": "TUT_04_COMPLETE",
     "guard": {"pieces": ["G-T01", "B-T01", "C-T01", "BUS-T", "LAMP-T"], "until": {"reading": ["E-T01", "<", 1.0]}, "lock": ["T04_lock_t"],
               "accident": ["arc", "drone_hit"], "reset": ["G-T01", "B-T01", "C-T01", "BUS-T", "LAMP-T"], "say": "T04_arc",
               "restore": {"power": True, "ctrls": ["K-BT", "E-T02"], "readings": ["E-T01", "E-T02"]}},
     "steps": [
        {"id": "test", "text": t("用测量（1）测 E-T01", "MEASURE (1): TEST POINT E-T01"), "tools": [1], "done": {"reading": ["E-T01", ">", 1.0]},
         "in": ["T04_in1", "T04_in2"], "out": ["T04_backup_t"], "target": {"ctrl": "E-T01"}, "hint": "T04_h1", "auto": [19.3, -1.9]},
        {"id": "isolate", "text": t("断开备用电池的开关 K-BT（4）", "WRENCH (4): OPEN BATTERY SWITCH K-BT"), "tools": [4], "done": {"switch": ["K-BT", False]},
         "in": ["T04_backup_l"], "target": {"ctrl": "K-BT"}, "auto": [19.0, -1.9]},
        {"id": "retest", "text": t("再测 E-T01", "MEASURE E-T01 AGAIN"), "tools": [1], "done": {"reading_after": ["E-T01", "isolate"]}, "out": ["T04_cap"], "target": {"ctrl": "E-T01"}},
        {"id": "bleed", "text": t("接上 E-T02 受控放电（4）", "WRENCH (4): PLUG IN BLEED E-T02"), "tools": [4], "done": {"charge": ["C-T01", "<", 0.002]}, "target": {"ctrl": "E-T02"}, "auto": [19.0, -1.5]},
        {"id": "verify", "text": t("再测 E-T01，确认 0 V", "MEASURE E-T01: CONFIRM 0 V"), "tools": [1], "done": {"reading": ["E-T01", "<", 1.0]}, "out": ["T04_ok_t"], "target": {"ctrl": "E-T01"}},
        {"id": "free", "text": t("拆下 G-T01 的螺栓和接头（4）", "WRENCH (4): FREE G-T01"), "tools": [3, 4], "done": {"free": "G-T01"}, "target": {"piece": "G-T01"}},
        {"id": "deliver", "text": t("完整送进设备回收口", "DELIVER IT WHOLE TO EQUIPMENT"), "tools": [3, 4], "done": {"recovered": ["G-T01", "equip"]}, "out": ["T04_done"], "target": {"zone": "equip"}},
    ]},
    {"id": "TUT_05", "mode": "goal", "title": t("你漏了一根管子", "YOU MISSED A PIPE"), "done_flag": "TUT_05_COMPLETE", "steps": [
        {"id": "pump", "text": t("完整回收冷却泵 CP-T", "RECOVER COOLANT PUMP CP-T WHOLE"), "tools": [1, 2, 3, 4, 5], "done": {"recovered": ["CP-T", "any"]},
         "in": ["T05_in1", "T05_in2"], "hint": "T05_h3", "target": {"piece": "CP-T"}},
    ]},
    {"id": "TUT_06", "mode": "goal", "title": t("重的东西不会听你的", "HEAVY THINGS DON'T LISTEN"), "done_flag": "TUT_06_COMPLETE",
     "guard": {"pieces": [], "until": {}, "accident": ["furnace"], "reset": ["RT-T"], "say": "T06_boom"},
     "steps": [
        {"id": "frame", "text": t("清空框架", "CLEAR THE FRAME"), "tools": [1, 2, 3, 4, 5], "done": {"all_recovered": ["ARM-T", "BM-1", "BM-2", "RT-T", "ST-1", "ST-2"]},
         "in": ["T06_in"], "out": ["T06_done_t", "T06_done_l"], "hint": "T06_h3"},
    ]},
]

out = {"ship": "ts1", "lines": L, "lessons": LESSONS,
       # flight course of lesson 1, metres: three rings, a long dash ring, a stop box
       "rings": [[1.5, -6.0, 0.9], [5.5, -7.3, 0.9], [9.0, -5.6, 0.9]],
       "long_ring": [[11.0, -6.4], [16.0, -6.4], 0.9],
       "stop_box": [19.4, -6.9, 21.0, -5.5],
       "exam_offer": "T_exam_offer"}
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "..", "..", "ships", "ts1_course.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump(out, f, ensure_ascii=False, indent="\t")
print("ships/ts1_course.json: %d lines, %d lessons, %d steps" % (len(L), len(LESSONS), sum(len(l["steps"]) for l in LESSONS)))
