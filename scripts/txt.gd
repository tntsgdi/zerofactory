class_name Txt
# Chinese and English strings. Industrial codes (P-C01, 108.1 kPa) stay as they are.

static var zh := true
static var hints := true
static var assist := true
static var certified := false     # passed the training course (or skipped it)
static var cert_kind := ""        # "full" | "skipped"
static var exam_grade := ""       # best apprentice assessment: A B C
static var hint_tier := "standard"   # guided | standard | hardcore
static var clues: Array = []          # story clues filed in the company archive
static var vol_master := 1.0
static var vol_music := 0.8
static var vol_sfx := 0.9
static var quality := "high"          # high | low (no glow, no anti-aliasing)
static var cfg_path := CFG            # tests point this at their own file
static var test_zh := true            # the language a test runs in
static var chapter_done := false      # chapter one seen to the end
const TIERS := ["guided", "standard", "hardcore"]
const CFG := "user://zeropower_settings.cfg"

const S := {
	# settings
	"m_settings": ["设置", "SETTINGS"],
	"s_title": ["设置", "SETTINGS"],
	"s_vol_master": ["主音量", "MASTER VOLUME"],
	"s_vol_music": ["音乐", "MUSIC"],
	"s_vol_sfx": ["音效", "SOUND EFFECTS"],
	"s_quality": ["画质", "PICTURE"],
	"s_q_high": ["高", "HIGH"],
	"s_q_low": ["低", "LOW"],
	"s_lang": ["语言", "LANGUAGE"],
	"s_back": ["返回", "BACK"],
	"s_keys": ["↑↓ 选择 · ←→ 调整 · Esc 返回", "↑↓ SELECT · ←→ ADJUST · ESC BACK"],
	# apprentice assessment
	"p_e07": ["辅助设备 E-07", "AUX UNIT E-07"],
	"p_e07_lid": ["设备舱盖板", "BAY LID"],
	"p_e07_jb": ["接线盒", "JUNCTION BOX"],
	"p_e07_socket": ["墙上插座", "WALL SOCKET"],
	"p_e07_bracket": ["支架", "BRACKET"],
	"p_e07_panel": ["检修面板", "INSPECTION PANEL"],
	"room_EX": ["E-07 设备舱", "E-07 BAY"],
	"ex_goal": ["考核目标：完整回收设备 E-07", "OBJECTIVE: RECOVER UNIT E-07 WHOLE"],
	"ex_known": ["已知条件：无有效现场检测记录", "KNOWN: NO VALID SITE READINGS"],
	"ex_q": ["Q  求提示（评级会记一笔）", "Q  HINT (IT GOES ON THE GRADE)"],
	"ex_hints": ["已用提示 %d 次", "HINTS USED: %d"],
	"ex_l1": ["这是最后一个练习。我不提示你该怎么拆，自己检查。", "Last exercise. I won't tell you how to take it apart. Check it yourself."],
	"ex_l2": ["放心，训练场出不了大事。", "Relax, nothing big can go wrong on the training rig."],
	"ex_l3": ["不过设备拆坏了，成绩就会很难看。", "But break the unit and your grade will look ugly."],
	"ex_hint_cost": ["想要提示？可以。不过最后的评级会记一笔。", "Want a hint? Fine. It goes on the grade."],
	"ex_free": ["好，继续送回收口。", "Good. Now into the bay."],
	"ex_broken": ["设备已经损坏了。把剩下的部分回收吧，至少把活干完。", "The unit's damaged. Recover what's left — at least finish the job."],
	"ex_a": ["不错。看来你确实知道自己在干什么了。", "Not bad. Looks like you do know what you're doing."],
	"ex_bc": ["能拆完就行。后面还有得练。", "Getting it done is what counts. Plenty of practice ahead."],
	"ex_done": ["考核完成", "ASSESSMENT COMPLETE"],
	"ex_incomplete": ["考核未完成", "ASSESSMENT INCOMPLETE"],
	"ex_g_A": ["独立完成 · 安全回收 · 设备完整", "UNAIDED · SAFE · INTACT"],
	"ex_g_B": ["已回收 · 用过提示或有轻微损坏", "RECOVERED · WITH A HINT OR LIGHT DAMAGE"],
	"ex_g_C": ["已拆下 · 设备严重损坏", "REMOVED · BADLY DAMAGED"],
	"ex_g_none": ["可以重新考核，也可以直接接合同", "Take it again, or go straight to the contract"],
	"ex_review": ["事故复盘", "INCIDENT REVIEW"],
	"ex_clean": ["没有事故。", "No incidents."],
	"ex_retake": ["重新考核", "TAKE IT AGAIN"],
	"m_abandon": ["放弃考核", "ABANDON ASSESSMENT"],
	"rv_w_pressure": ["打开了还带压的舱室。", "Opened a compartment that still held pressure."],
	"rv_y_pressure": ["依据不对：动手前没有在连通舱室的测点测到压力，也没有先抽空。", "The call: no pressure reading on a port that reaches the room, no draining, before opening it."],
	"rv_w_power": ["在带电时拆了电气连接。", "Undid an electrical connection while it was live."],
	"rv_y_power": ["设备看起来停着不代表断电：先断开储能、放电，再在测点测到 0 V。", "Looking stopped is not off: isolate the storage, bleed it, then read 0 V at a test point."],
	"rv_w_tied": ["拖动时还有连接没解开，被硬扯断了（%s）。", "Pulled while something still held it; it tore (%s)."],
	"rv_y_tied": ["拖之前先用测量工具看它有几处固定、几条线，全部解开再拉。", "Before pulling, inspect it for fixings and lines, and undo every one."],
	"rv_w_tied_lines": ["拖动时管线或电缆还连着，被硬扯断了（%s）。", "Pulled with a pipe or cable still on; it tore (%s)."],
	"rv_y_tied_lines": ["固定件、管道和电缆是各自独立的连接：每一条都要先解开。", "Fixings, pipes and cables are separate connections: undo each one first."],
	"rv_w_tied_hidden": ["拖动时检修面板后面还有一处固定，被硬扯断了（%s）。", "Pulled with a fixing still on behind the inspection panel; it tore (%s)."],
	"rv_y_tied_hidden": ["测量工具报的固定数比看得见的多：先拆检修面板，找到藏着的那一处。", "The inspection counted more fixings than you could see: take the panel off and find the hidden one."],
	"rv_w_tank": ["储气罐超压爆了。", "A gas bottle burst."],
	"rv_y_tank": ["舱抽空了不代表罐子空了：罐子要单独接软管。", "An empty room doesn't mean empty bottles: hose them separately."],
	"rv_w_drain": ["管路里的液体漏了出来。", "Fluid got out of a line."],
	"rv_y_drain": ["拆管接头之前先抽空、降温。", "Drain and cool a line before undoing it."],
	"rv_w_cut": ["激光切到了设备本体（%s）。", "The laser went into the unit itself (%s)."],
	"rv_y_cut": ["能拆就别切：先找固定件和连接。", "Undo before you cut: find the fixings and connections first."],
	"rv_w_impact": ["零件撞得太猛，损坏了（%s）。", "A piece hit something too hard (%s)."],
	"rv_y_impact": ["拖运时放慢，提前减速。", "Haul slower and brake early."],
	"rv_w_hazard": ["危险品进了熔炉或起了火。", "Something hazardous went into the furnace, or caught fire."],
	"rv_y_hazard": ["看清去向：有残留的送危险品回收口。", "Check where it goes: anything with residue goes to the hazmat mouth."],
	"rv_w_hint": ["用过 %s 次提示。", "Used %s hint(s)."],
	"rv_y_hint": ["提示会记入评级，最高 B。", "Hints go on the grade: B at best."],
	# story
	"st_skip": ["任意键跳过", "ANY KEY TO SKIP"],
	"st_to_title": ["任意键返回标题", "ANY KEY: TITLE"],
	"st_found": ["物件 %d / %d", "FOUND %d / %d"],
	"st_go_on": ["任意键继续   ·   R  重新拆一艘", "ANY KEY: CONTINUE   ·   R  ANOTHER HERON"],
	"end_warn": ["梁工：确认要结束？剩下的结构会按废料处理，收益比你自己拆低。", "LIANG: You sure? What's left goes as scrap — less than you'd get taking it apart."],
	# hint tiers
	"tier_label": ["提示档位", "HINTS"],
	"tier_guided": ["引导", "GUIDED"],
	"tier_standard": ["标准（推荐）", "STANDARD (RECOMMENDED)"],
	"tier_hardcore": ["硬核", "HARDCORE"],
	"tier_desc_guided": ["已知危险会给出具体的检查建议", "Concrete checks for known dangers"],
	"tier_desc_standard": ["只提醒还有未处理的系统，不说怎么处理", "Only says what is still unresolved"],
	"tier_desc_hardcore": ["只有仪器读数和真实报警", "Instruments and real alarms only"],
	"tier_rule": ["三档用同一套模拟：只改提示，不改船、读数、价值和事故", "Same simulation in all three: only the hints differ"],
	"m_tier": ["提示：%s", "HINTS: %s"],
	"tier_now": ["提示档位：%s", "HINTS: %s"],
	"as_p_g": ["%s 压力未验证。先在 %s 测一下。", "%s pressure not verified. Measure at %s first."],
	"as_p_g_dl": ["%s 压力未验证。%s 和舱室之间隔着阀门 %s，先开阀再测。", "%s pressure not verified. Valve %s sits between %s and the room — open it, then measure."],
	"as_p_g_known": ["%s 里还有 %d kPa，先接软管抽空。", "%s still holds %d kPa. Hose it down first."],
	"as_p_g_none": ["%s 压力未验证，先找个能测的地方。", "%s pressure not verified. Find somewhere to measure it."],
	"as_p_s": ["这个区域的检测记录还没确认。", "This area's survey record isn't confirmed yet."],
	"as_v_g": ["%s 可能还带电。先断开电源、放电，再测到 0 V。", "%s may still be live. Isolate, bleed, measure 0 V first."],
	"as_v_s": ["现在的数据和事故报告对不上，最好再查一下。", "The readings don't match the incident report. Better check again."],
	"as_c_g": ["先确认所有连接都断开了。这东西还连着别的设备。", "Make sure every connection's undone first. This thing's still hooked to other equipment."],
	"as_c_s": ["%s 还有连接未解除。", "%s: CONNECTIONS REMAIN."],
	"as_f_g": ["管里还有液体：先用 %s 抽空再拆。", "Still fluid in that line: drain it at %s first."],
	"as_f_g_np": ["管里还有液体：先抽空再拆。", "Still fluid in that line: drain it first."],
	"as_f_s": ["%s 管路状态：未处理。", "%s LINE: UNRESOLVED."],
	"as_t_g": ["管路还很烫：热源停下来以后要等它降温。", "That line is hot: stop the heat source and let it cool."],
	"as_t_s": ["管路温度：未处理。", "LINE TEMPERATURE: UNRESOLVED."],
	"as_h_g": ["%s 里还有危险残留，送危险品回收口。", "%s still holds hazardous contents — hazmat mouth."],
	"as_h_s": ["%s 的去向再确认一下。", "%s: CHECK WHERE IT GOES."],
	"as_cl_g": ["附近有推进剂云团，别在里面开激光。", "Propellant in the air here — keep the laser out of it."],
	"as_cl_s": ["附近有可燃气体。", "FLAMMABLE GAS NEARBY."],
	"as_port_g": ["看看这接口接到哪儿，别只盯着表上的数字。", "Check what this port is connected to, not just the number."],
	"rc_title": ["训练回想", "FROM TRAINING"],
	"rc_l": ["和 TS-1 第 %d 课一样", "SAME AS TS-1 LESSON %d"],
	"notes": ["笔记", "NOTES"],
	"rc_s_path": ["测量通路", "WHAT THE GAUGE SEES"],
	"rc_s_backup": ["备用电源", "BACKUP POWER"],
	"rc_s_blow": ["带压舱室", "PRESSURISED ROOM"],
	"rc_s_tank": ["储气罐", "GAS BOTTLES"],
	"rc_s_hot": ["热源", "HEAT SOURCE"],
	"rc_s_guard": ["护板", "GUARD PLATE"],
	"rc_s_tied": ["连接", "CONNECTIONS"],
	"rc_s_heavy": ["超重", "OVERWEIGHT"],
	"rc_v02": ["还记得训练里的 V-02 吗。", "Remember V-02 in training."],
	"rc_volts": ["面板说停了，测点不这么说。和训练时一样。", "The panel says stopped. The test point disagrees. Like in training."],
	"rc_blow": ["……还好不是人。", "...Good thing nobody was in there."],
	"rc_tank": ["舱抽空了，罐子可没有。", "The room's empty. The bottles aren't."],
	"rc_hot": ["热源还在转，它就凉不下来。", "While the heat source runs, it won't cool down."],
	"rc_guard": ["护板变形了，拆掉它再接管。", "The guard's bent. Take it off, then connect."],
	"rc_pull": ["连着呢，和训练那台泵一样。", "Still connected — just like that pump in training."],
	"rc_heavy": ["超重。和训练那根梁一样，想办法分开。", "Overweight. Like that beam in training — split it."],
	# training course
	"tut_course": ["训练 · TS-1 训练舱段", "TRAINING · TS-1 SECTION"],
	"tut_lesson": ["第 %d 课", "LESSON %d"],
	"tut_lockstep": ["跟着做", "STEP BY STEP"],
	"tut_goal": ["只给目标", "GOAL ONLY"],
	"tut_q": ["按 Q 请求提示", "Q FOR A HINT"],
	"tut_liang": ["工程师 · 梁工", "ENGINEER · LIANG"],
	"tut_term": ["船坞终端", "BERTH TERMINAL"],
	"tut_cert": ["零压认证", "ZERO-PRESSURE"],
	"tut_done": ["训练完成", "TRAINING COMPLETE"],
	"tut_exam": ["学徒考核", "APPRENTICE ASSESSMENT"],
	"tut_contract": ["接第一份合同", "TAKE THE FIRST CONTRACT"],
	"tool_locked": ["这一步还用不到这件工具", "NOT THIS TOOL YET"],
	"interlock": ["训练安全联锁", "TRAINING INTERLOCK"],
	"m_skip": ["跳过训练", "SKIP TRAINING"],
	"t_train": ["训练", "TRAINING"],
	# saves
	"save_recovered": ["存档损坏，已从上一次自动存档恢复", "SAVE DAMAGED · RESTORED FROM THE PREVIOUS AUTOSAVE"],
	# dock
	"net": ["碎屑收集网", "DEBRIS NET"],
	"zone_equip": ["设备回收", "EQUIPMENT"],
	"zone_metal": ["金属熔炉", "FURNACE"],
	"zone_hazard": ["危险品回收", "HAZMAT"],
	# tools
	"tool_1": ["测量", "MEASURE"],
	"tool_2": ["激光切割", "LASER"],
	"tool_3": ["磁力抓钩", "GRAPPLE"],
	"tool_4": ["维护工具", "WRENCH"],
	"tool_5": ["气液回收", "HOSE"],
	"mode_recover": ["回收", "RECOVER"],
	"mode_vent": ["排放", "VENT"],
	"hose_recover": ["软管模式：回收到储罐", "HOSE: RECOVER TO TANK"],
	"hose_vent": ["软管模式：排向真空（快，但没有回收收益）", "HOSE: VENT TO SPACE (FAST, NO VALUE)"],
	# hover reasons
	"out_of_range": ["超出 4 m 作业范围", "OUT OF 4 m REACH"],
	"range": ["超出作业范围", "OUT OF REACH"],
	"hidden": ["看不见舱内 · 先打开它", "CAN'T SEE INSIDE · OPEN IT FIRST"],
	"blocked_guard": ["被变形护板挡住", "BEHIND A BENT GUARD PLATE"],
	"covered": ["被检修盖挡住", "BEHIND A SERVICE COVER"],
	"nothing": ["没有可抓的东西", "NOTHING TO GRAB"],
	"tether_snap": ["牵引脱开", "TETHER LOST"],
	# actions shown at the cursor
	"act_measure": ["测量", "MEASURE"],
	"act_inspect": ["检查", "INSPECT"],
	"act_unbolt": ["拧下螺栓", "UNBOLT"],
	"act_unlock": ["解开锁扣", "UNLOCK"],
	"act_clamp": ["松开船坞夹具", "RELEASE CLAMP"],
	"act_unplug": ["拔下接头", "DISCONNECT"],
	"act_valve_open": ["打开阀门", "OPEN VALVE"],
	"act_valve_close": ["关闭阀门", "CLOSE VALVE"],
	"act_switch_on": ["合上", "CLOSE"],
	"act_switch_off": ["断开", "OPEN"],
	"act_remote": ["发送停机指令", "SEND SHUTDOWN"],
	"act_stop": ["本地停机", "LOCAL STOP"],
	"act_socket": ["接入 / 断开船坞辅助电源", "DOCK AUX POWER"],
	"act_discharge": ["接入 / 断开受控放电", "CONTROLLED DISCHARGE"],
	"act_door": ["开关舱门", "DOOR"],
	"act_hatch": ["开关货舱门", "CARGO HATCH"],
	"act_jam": ["解除卡滞", "CLEAR JAM"],
	"act_hose_on": ["接上软管", "CONNECT HOSE"],
	"act_hose_off": ["取下软管", "DISCONNECT HOSE"],
	"act_grab": ["抓取", "GRAB"],
	# recovery
	"scrap_metal": ["废金属", "SCRAP"],
	"equip_as_scrap": ["完整设备当废金属熔掉了", "WHOLE EQUIPMENT MELTED AS SCRAP"],
	"rej_hazard": ["含危险残余物 · 送危险品回收", "HAZARDOUS CONTENTS · HAZMAT BAY"],
	"rej_scrap": ["废料 · 送金属熔炉", "SCRAP · FURNACE"],
	"rej_mixed": ["还连着废金属 · 先拆开", "STILL ATTACHED TO SCRAP · SEPARATE IT"],
	"rej_not_hazard": ["不是危险品 · 送设备回收", "NOT HAZARDOUS · EQUIPMENT BAY"],
	"loss_furnace": ["熔炉爆燃", "FURNACE FLASH"],
	"loss_drone": ["R-02 损毁", "R-02 LOST"],
	"loss_fire": ["推进剂起火", "PROPELLANT FIRE"],
	# events
	"impact_damage": ["撞击损伤", "IMPACT DAMAGE"],
	"hit_hard": ["高速撞击", "HARD IMPACT"],
	"arc_hit": ["电弧！", "ARC FLASH!"],
	"burst_hit": ["容器爆裂", "VESSEL BURST"],
	"fire_hit": ["起火", "FIRE"],
	"scald": ["高温冷却液", "SCALDING COOLANT"],
	"jet_hit": ["被气流击中", "CAUGHT IN THE JET"],
	"live_unplug": ["带电拔插 · 电弧", "LIVE DISCONNECT · ARC"],
	"confirm_cut": ["%s · 再按一次左键确认切入", "%s · CLICK AGAIN TO CUT INTO IT"],
	"equip_ruined": ["%s 已损坏", "%s RUINED"],
	"leak_fuel": ["推进剂泄漏", "PROPELLANT LEAK"],
	"leak_coolant": ["冷却液喷出", "COOLANT SPRAY"],
	"cable_cut": ["切断 %s", "%s CUT"],
	"still_fixed": ["仍有 %s 个固定件", "%s FIXINGS STILL HOLD IT"],
	"too_heavy": ["%s t · 超过 3 t 上限", "%s t · OVER THE 3 t LIMIT"],
	"torn_free": ["扯断了连接", "TORN LOOSE"],
	"clamp_off": ["%s 已松开", "%s RELEASED"],
	"pipe_full": ["管内仍有流体", "STILL FULL OF FLUID"],
	"pipe_hot": ["%s °C · 太烫", "%s °C · TOO HOT"],
	"valve_open": ["%s 打开", "%s OPEN"],
	"valve_closed": ["%s 关闭", "%s CLOSED"],
	"sw_on": ["%s 合上", "%s CLOSED"],
	"sw_off": ["%s 断开", "%s OPEN"],
	"remote_sent": ["G-01：已发送停机指令", "G-01: SHUTDOWN REQUESTED"],
	"gen_stopped": ["G-01 本地停机", "G-01 STOPPED LOCALLY"],
	"aux_on": ["船坞辅助电源接入", "DOCK AUX POWER ON"],
	"aux_off": ["船坞辅助电源断开", "DOCK AUX POWER OFF"],
	"discharge_on": ["受控放电接入", "DISCHARGE LEAD ON"],
	"discharge_off": ["受控放电断开", "DISCHARGE LEAD OFF"],
	"discharge_refused": ["母线仍有电源 · 放电装置跳开", "BUS STILL FED · DISCHARGE TRIPPED"],
	"no_power": ["没有电 · 接入船坞辅助电源", "NO POWER · CONNECT DOCK AUX"],
	"jam_cleared": ["卡滞已解除", "JAM CLEARED"],
	"hatch_jammed": ["货舱门卡住了", "HATCH IS JAMMED"],
	"hose_off": ["%s 软管取下", "%s HOSE OFF"],
	"hose_on_recover": ["%s 回收中", "%s RECOVERING"],
	"hose_on_vent": ["%s 排放中", "%s VENTING"],
	"room_open": ["%s 已打开", "%s OPEN"],
	"blowout": ["爆发性失压 · %s", "EXPLOSIVE DECOMPRESSION · %s"],
	"room_A": ["A 驾驶舱", "A COCKPIT"],
	"room_B": ["B 生活舱", "B QUARTERS"],
	"room_C": ["C 货舱", "C CARGO HOLD"],
	"room_D": ["D 电力舱", "D POWER ROOM"],
	"room_E": ["E 维修舱", "E MAINTENANCE"],
	"room_F": ["F 推进组件", "F PROPULSION"],
	"room_TC": ["TC-1 密封舱", "TC-1 SEALED BAY"],
	# instruments & inspection
	"inst_pressure": ["压力检测仪", "PRESSURE GAUGE"],
	"inst_volts": ["电气检测仪", "VOLTAGE TESTER"],
	"inst_fluid": ["流体检测", "FLUID GAUGE"],
	"inst_temp": ["接触测温", "CONTACT THERMOMETER"],
	"inst_inspect": ["目视 / 接触检查", "VISUAL / CONTACT CHECK"],
	"j_bolt": ["螺栓", "BOLT(S)"],
	"j_weld": ["焊缝", "WELD(S)"],
	"j_lock": ["锁扣", "LOCK(S)"],
	"j_clamp": ["夹具", "CLAMP(S)"],
	"j_line": ["线缆/管线", "LINE(S)"],
	"j_none": ["无固定", "LOOSE"],
	"stale": ["已过期", "STALE"],
	"read_at": ["测点", "AT"],
	"read_by": ["仪器", "BY"],
	"read_time": ["时间", "TIME"],
	# pieces
	"p_console": ["驾驶控制台", "FLIGHT CONSOLE"],
	"p_nav": ["导航电脑", "NAV COMPUTER"],
	"p_blackbox": ["黑匣子", "FLIGHT RECORDER"],
	"p_cover": ["检修盖", "SERVICE COVER"],
	"p_gastank": ["储气罐", "GAS BOTTLE"],
	"p_env": ["环境控制单元", "ENV CONTROL UNIT"],
	"p_bunk": ["铺位", "BUNK"],
	"p_cargo1": ["货柜 · 工业金属", "CONTAINER · METAL"],
	"p_cargo2": ["货柜 · 精密机械", "CONTAINER · PRECISION"],
	"p_cargo3": ["货柜 · 电子元件", "CONTAINER · ELECTRONICS"],
	"p_hook": ["吊钩小车", "CRANE TROLLEY"],
	"p_lamp": ["舱灯", "LAMP"],
	"p_gen": ["主电源模块", "MAIN POWER MODULE"],
	"p_ts_cover": ["检修盖", "SERVICE COVER"],
	"p_ts_shell": ["外壳板", "SHELL PLATE"],
	"p_ts_power": ["主电源模块", "MAIN POWER MODULE"],
	"p_ts_battery": ["备用蓄电池", "BACKUP BATTERY"],
	"p_ts_cap": ["电容模块", "CAPACITOR"],
	"p_ts_bus": ["配电盒", "JUNCTION BOX"],
	"p_ts_lamp": ["状态灯", "STATUS LAMP"],
	"p_ts_pump": ["冷却泵", "COOLANT PUMP"],
	"p_ts_manifold": ["管汇", "MANIFOLD"],
	"p_ts_armor": ["外部装甲", "ARMOUR PLATE"],
	"p_ts_strut": ["支撑框架", "SUPPORT STRUT"],
	"p_ts_beam": ["主梁模块", "MAIN BEAM MODULE"],
	"p_ts_tank": ["残液罐", "RESIDUE TANK"],
	"p_battery": ["蓄电池", "BATTERY"],
	"p_cap": ["储能电容", "CAPACITOR BANK"],
	"p_swb": ["配电柜", "SWITCHBOARD"],
	"p_pump": ["冷却泵", "COOLANT PUMP"],
	"p_cabinet": ["工具柜", "TOOL CABINET"],
	"p_radiator": ["散热器", "RADIATOR"],
	"p_module": ["维修组件", "REPAIR MODULE"],
	"p_engf": ["发动机前部接口", "ENGINE FEED UNIT"],
	"p_engc": ["中央推进组件", "ENGINE CORE"],
	"p_shroud": ["推进组件护罩", "ENGINE SHROUD"],
	"p_engn": ["尾部喷口", "NOZZLE"],
	"p_aux": ["辅助推进器", "AUX THRUSTER"],
	"p_fueltank": ["推进剂储罐", "PROPELLANT TANK"],
	"p_guard": ["护板", "GUARD PLATE"],
	"p_panel": ["电力控制面板", "POWER PANEL"],
	"k_hull": ["外壳板", "HULL PLATE"],
	"k_hatch": ["货舱门", "CARGO HATCH"],
	"k_bulkhead": ["舱壁", "BULKHEAD"],
	"k_door": ["舱门", "DOOR"],
	"k_deck": ["甲板", "DECK"],
	"k_keel": ["龙骨", "KEEL"],
	"k_rib": ["肋骨框架", "FRAME"],
	"k_rail": ["吊装轨道", "CRANE RAIL"],
	"k_beam": ["推进区纵梁", "TRUSS BEAM"],
	"k_strut": ["支撑杆", "STRUT"],
	"k_equip": ["设备残骸", "WRECKED EQUIPMENT"],
	"k_fixture": ["附件", "FITTING"],
	# hud
	"contract": ["拆解合同", "SALVAGE CONTRACT"],
	"ship": ["GR-7「灰鹭号」中型货运船 · 42 m", "GR-7 GREY HERON · MEDIUM FREIGHTER · 42 m"],
	"must": ["强制回收", "MUST RECOVER"],
	"rate": ["回收率", "RECOVERY"],
	"target": ["目标", "TARGET"],
	"income": ["合同收益", "CONTRACT INCOME"],
	"integrity": ["完好度", "INTEGRITY"],
	"speed": ["速度", "SPEED"],
	"blueprint": ["出厂图纸 · 仅代表原始设计", "FACTORY DRAWING · ORIGINAL DESIGN ONLY"],
	"keys": ["WASD 移动 · Shift 冲刺 · Space 刹停 · F 飞行稳定 · 1–5 工具 · Tab 图纸 · C 合同 · Esc 菜单", "WASD MOVE · SHIFT BURN · SPACE BRAKE · F ASSIST · 1–5 TOOLS · TAB DRAWING · C CONTRACT · ESC MENU"],
	# contract card
	"c_title": ["SALVAGE CONTRACT GR-001 · 未开工", "SALVAGE CONTRACT GR-001 · NOT STARTED"],
	"c_req": ["合同要求", "REQUIREMENTS"],
	"c_req1": ["不发生重大船坞事故", "NO MAJOR DOCK ACCIDENT"],
	"c_req2": ["强制回收：黑匣子 BB-01、主电源模块 G-01（完整送设备回收）", "MUST RECOVER: BB-01 RECORDER, G-01 POWER MODULE (WHOLE, TO EQUIPMENT BAY)"],
	"c_req3": ["回收至少 70% 可回收价值（总值 $120,000）", "RECOVER AT LEAST 70% OF $120,000"],
	"c_req4": ["拆除整艘船，清空船坞", "TAKE THE WHOLE SHIP APART"],
	"c_log": ["最后一次船载记录 · 退役前 17 小时 · 未验证", "LAST ONBOARD LOG · 17 h BEFORE RETIREMENT · UNVERIFIED"],
	"c_log1": ["货舱压力", "CARGO HOLD PRESSURE"],
	"c_log1v": ["数据传输中断", "DATA LINK LOST"],
	"c_log2": ["主电源", "MAIN POWER"],
	"c_log2v": ["收到停止指令", "STOP COMMAND RECEIVED"],
	"c_log3": ["蓄电池", "BATTERY"],
	"c_log3v": ["84%", "84%"],
	"c_log4": ["推进剂储量", "PROPELLANT"],
	"c_log4v": ["约 35%", "ABOUT 35%"],
	"c_log5": ["维修舱", "MAINTENANCE BAY"],
	"c_log5v": ["气密故障报警", "SEAL FAILURE ALARM"],
	"c_brief": ["事故简报：推进系统维护期间尾部设备事故，船员已撤离。现场未完成危险能源隔离检查，所有历史安全状态须重新验证。", "INCIDENT: AFT EQUIPMENT ACCIDENT DURING PROPULSION MAINTENANCE. CREW EVACUATED. HAZARDOUS ENERGY ISOLATION WAS NEVER VERIFIED — RE-CHECK EVERYTHING."],
	"c_drawing": ["出厂工程图：按 Tab 随时查看（只代表原始设计）", "FACTORY DRAWING: PRESS TAB ANY TIME (ORIGINAL DESIGN ONLY)"],
	"c_start": ["开工  ·  空格 / 点击", "BEGIN  ·  SPACE / CLICK"],
	"c_fee": ["合同费用 $9,000 · 无时限", "CONTRACT FEE $9,000 · NO TIME LIMIT"],
	# menu
	"m_resume": ["继续", "RESUME"],
	"m_end": ["提前结束合同", "END CONTRACT NOW"],
	"m_lang": ["语言：中文", "LANGUAGE: ENGLISH"],
	"m_hints": ["提示：开", "HINTS: ON"],
	"hints_auto_on": ["自动提示：开（卡住时梁工会提醒）", "AUTO HINTS ON (LIANG SPEAKS UP WHEN YOU'RE STUCK)"],
	"hints_auto_off": ["自动提示：关（按 Q 仍可求助）", "AUTO HINTS OFF (Q STILL ASKS)"],
	"m_hints_off": ["提示：关", "HINTS: OFF"],
	"m_title": ["保存并返回标题", "SAVE AND QUIT TO TITLE"],
	"m_paused": ["已暂停", "PAUSED"],
	"m_confirm": ["再点一次确认", "CLICK AGAIN TO CONFIRM"],
	# ending
	"e_done": ["GR-7 DISASSEMBLY COMPLETE", "GR-7 DISASSEMBLY COMPLETE"],
	"e_early": ["合同提前结束", "CONTRACT CLOSED EARLY"],
	"e_contract": ["拆解合同", "SALVAGE CONTRACT"],
	"e_rate": ["舰体有效回收率", "EFFECTIVE RECOVERY"],
	"e_equip": ["设备完整回收", "EQUIPMENT RECOVERED WHOLE"],
	"e_metal": ["金属与零件", "METAL & PARTS"],
	"e_fluid": ["气体与流体回收", "GAS & FLUID RECOVERY"],
	"e_loss": ["事故损失", "ACCIDENT LOSSES"],
	"e_fee": ["运营及合同费用", "OPERATIONS & FEES"],
	"e_net": ["合同净收益", "NET CONTRACT PROFIT"],
	"e_time": ["用时", "TIME"],
	"e_must_ok": ["强制回收完成", "MANDATORY ITEMS RECOVERED"],
	"e_must_no": ["强制回收未完成", "MANDATORY ITEMS MISSING"],
	"grade_0": ["未达标", "SUBSTANDARD"],
	"grade_1": ["合格", "PASS"],
	"grade_2": ["优良", "FINE"],
	"grade_3": ["卓越", "PRISTINE"],
	"e_again": ["R  重新拆一艘   ·   M  返回标题", "R  ANOTHER HERON   ·   M  TITLE"],
	"e_best": ["最佳", "BEST"],
	# title
	"t_title": ["零压拆船厂", "ZERO PRESSURE"],
	"t_sub": ["ZERO PRESSURE · 真空拆船", "ORBITAL SHIPBREAKING"],
	"t_new": ["接下合同", "TAKE THE CONTRACT"],
	"t_continue": ["继续拆解", "CONTINUE"],
	"t_quit": ["退出", "QUIT"],
	"t_note": ["拆解合同 GR-001 · GR-7 灰鹭号", "CONTRACT GR-001 · GR-7 GREY HERON"],
	# hints (first time each)
	"hint_start": ["先别急着切。用 1 测量工具点外壳上的测压口和测点，看看这艘船现在的真实状态。", "Don't cut yet. Take tool 1 to the ports and test points on the hull — find out what this ship is really like now."],
	"hint_dead_leg": ["读数来自测压口实际连通的那一段。按 Tab 看图纸：测压口和舱室之间可能还隔着阀门。", "A gauge reads whatever its port is connected to. Press Tab: there may be a valve between the port and the room."],
	"hint_dead_leg_hose": ["阀门关着，软管只能抽到阀门外侧那一小段空管。", "With the valve shut the hose only reaches the empty stub outside it."],
	"hint_not_off": ["控制台显示的是指令，不是实测：母线仍然有电。", "The panel shows what was commanded, not what is true: the bus is still live."],
	"hint_remote": ["指令已发出。它真的停了吗？用测量工具去测试点验证。", "Command sent. Did it actually stop? Verify at a test point."],
	"hint_measured": ["读数会标出仪器、测点和时间；系统一变化，旧读数就会变灰过期。", "Readings carry instrument, point and time; when the system changes they turn grey and stale."],
	"hint_equip_cut": ["激光遇到设备会停下。切进去设备就成了废料——想完整回收，用 4 维护工具拆它的固定件。", "The laser stops at equipment. Cutting into it turns it to scrap — use tool 4 on its fixings to take it out whole."],
	"hint_arc": ["带电部件一碰就是电弧。断开电源、放掉电容，再用电气检测仪确认 0 V。", "Live parts arc. Isolate the sources, bleed the capacitor, then confirm 0 V with the tester."],
	"hint_burst": ["储气罐和舱室是两回事：舱室抽空了，罐子里可能还有压力。", "A bottle is not its room: the room can be empty while the bottle is still full."],
	"hint_leak_fuel": ["推进剂泄漏会在附近形成危险区：别在里面用激光。", "Leaking propellant makes a hazard cloud — keep the laser out of it."],
	"hint_leak_coolant": ["冷却液会污染附近设备。先关两侧阀门、抽空、等温度降下来再拆。", "Coolant fouls nearby equipment. Close the valves, drain it and let it cool before you open the line."],
	"hint_fire": ["推进剂起火了。泄漏的地方离激光远一点。", "The propellant caught fire. Keep the laser away from leaks."],
	"hint_fixings": ["还连着东西。用 1 检查它有几个固定件，用 4 拆掉或用 2 切断。", "Something still holds it. Inspect it with 1, then undo the fixings with 4 or cut them with 2."],
	"hint_heavy": ["抓钩最多 3 t。切小一点，或者先拆下附属件。", "The grapple tops out at 3 t. Cut it smaller or take parts off first."],
	"hint_torn": ["硬扯会扯断锁扣和线缆，设备也跟着受损。下次先用 4 解开。", "Tearing breaks locks and lines and hurts the equipment. Undo them with 4 first."],
	"hint_pipe_full": ["管里还有流体。先关阀、用 5 抽空。", "Still full. Close the valves and drain it with tool 5."],
	"hint_pipe_hot": ["冷却回路很烫——发电机还在运转时它不会凉下来。", "The coolant loop is hot — it won't cool while the generator keeps running."],
	"hint_no_power": ["舱门电机没电。看看船坞有没有外接辅助电源的插座。", "No power for the door motors. Look for a dock aux power socket."],
	"hint_hatch_jam": ["舱门变形卡住了，先用 4 解除卡滞。", "The hatch is bent and jammed — clear the jam with tool 4 first."],
	"hint_hose": ["软管在后台抽，不用守着。按 5 可以切换回收 / 排放。", "The hose works in the background. Press 5 again to switch recover / vent."],
	"hint_blowout": ["带压舱室被切开会爆发性失压：货物被推撞，气体收益也没了。", "Cutting into a pressurised room blows it out: cargo gets thrown and the gas is lost."],
	"hint_discharge_refused": ["发电机或蓄电池还在给母线供电，先断开它们的开关。", "A generator or battery still feeds the bus — open their switches first."],
	"hint_free_body": ["零件脱离了。用 3 抓住它，拖或甩进对应的回收口。", "It's free. Grab it with 3 and haul or fling it into the right mouth."],
	"hint_impact": ["撞击会让设备折价。慢一点，或者用 Space 刹停。", "Impacts cost value. Slow down — Space brakes."],
	"hint_field": ["泊位上方和右侧是开放的。边缘有牵引场，会把漂出去的东西（包括你）轻轻拉回来。", "The berth is open above and to the right. A tractor field at the edge eases anything drifting out — you included — back in."],
	"assist_on": ["飞行稳定：开（松手悬停，自动抵消漂移）", "FLIGHT ASSIST ON (HOLDS POSITION, KILLS DRIFT)"],
	"assist_off": ["飞行稳定：关（纯真空惯性）", "FLIGHT ASSIST OFF (PURE INERTIA)"],
	"assist": ["稳定", "ASSIST"],
	"hint_drone_lost": ["R-02 损毁，新机已弹射。回到左侧机库可以免费修复。", "R-02 lost; a new one is on its way. The bay on the left repairs for free."],
}


static func t(key: String) -> String:
	var v = S.get(key)
	if v == null:
		return key
	return v[0] if zh else v[1]


static func has(key: String) -> bool:
	return S.has(key)


static func piece_name(p) -> String:
	if p == null:
		return ""
	if p.name_key != "":
		var n := t(p.name_key)
		return n + ("  " + p.tag if p.tag != "" else "")
	var k: String = "k_" + p.kind
	if p.tag != "":
		return t(k) + "  " + p.tag
	return t(k)


static func load_settings(testing: bool) -> void:
	zh = OS.get_locale_language() == "zh"
	if testing:
		zh = test_zh
		return
	var cf := ConfigFile.new()
	if cf.load(cfg_path) == OK:
		zh = cf.get_value("ui", "zh", zh)
		hints = cf.get_value("ui", "hints", true)
		assist = cf.get_value("ui", "assist", true)
		certified = cf.get_value("career", "certified", false)
		cert_kind = cf.get_value("career", "cert_kind", "")
		exam_grade = cf.get_value("career", "exam_grade", "")
		hint_tier = cf.get_value("ui", "hint_tier", "standard")
		clues = cf.get_value("career", "clues", [])
		chapter_done = cf.get_value("career", "chapter_done", false)
		vol_master = cf.get_value("audio", "master", 1.0)
		vol_music = cf.get_value("audio", "music", 0.8)
		vol_sfx = cf.get_value("audio", "sfx", 0.9)
		quality = cf.get_value("video", "quality", "high")


static func save_settings(testing: bool) -> void:
	if testing:
		return
	var cf := ConfigFile.new()
	cf.set_value("ui", "zh", zh)
	cf.set_value("ui", "hints", hints)
	cf.set_value("ui", "assist", assist)
	cf.set_value("career", "certified", certified)
	cf.set_value("career", "cert_kind", cert_kind)
	cf.set_value("career", "exam_grade", exam_grade)
	cf.set_value("ui", "hint_tier", hint_tier)
	cf.set_value("career", "clues", clues)
	cf.set_value("career", "chapter_done", chapter_done)
	cf.set_value("audio", "master", vol_master)
	cf.set_value("audio", "music", vol_music)
	cf.set_value("audio", "sfx", vol_sfx)
	cf.set_value("video", "quality", quality)
	cf.save(cfg_path)
