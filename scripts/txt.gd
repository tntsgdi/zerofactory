class_name Txt
# Chinese and English strings. Industrial codes (P-C01, 108.1 kPa) stay as they are.

static var zh := true
static var hints := true
static var assist := true
const CFG := "user://zeropower_settings.cfg"

const S := {
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
	# instruments & inspection
	"inst_pressure": ["压力检测仪", "PRESSURE GAUGE"],
	"inst_volts": ["电气检测仪", "VOLTAGE TESTER"],
	"inst_fluid": ["流体检测", "FLUID GAUGE"],
	"inst_temp": ["接触测温", "CONTACT THERMOMETER"],
	"inst_inspect": ["目视 / 接触检查", "VISUAL / CONTACT CHECK"],
	"j_bolt": ["螺栓", "BOLTS"],
	"j_weld": ["焊缝", "WELDS"],
	"j_lock": ["锁扣", "LOCKS"],
	"j_clamp": ["夹具", "CLAMPS"],
	"j_line": ["线缆/管线", "LINES"],
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
	"contract": ["拆解合同 #001", "SALVAGE CONTRACT #001"],
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
	"c_title": ["SALVAGE CONTRACT #001 · 未开工", "SALVAGE CONTRACT #001 · NOT STARTED"],
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
	"m_hints_off": ["提示：关", "HINTS: OFF"],
	"m_title": ["保存并返回标题", "SAVE AND QUIT TO TITLE"],
	"m_paused": ["已暂停", "PAUSED"],
	"m_confirm": ["再点一次确认", "CLICK AGAIN TO CONFIRM"],
	# ending
	"e_done": ["GR-7 DISASSEMBLY COMPLETE", "GR-7 DISASSEMBLY COMPLETE"],
	"e_early": ["合同提前结束", "CONTRACT CLOSED EARLY"],
	"e_contract": ["拆解合同 #001", "SALVAGE CONTRACT #001"],
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
	"t_note": ["拆解合同 #001 · GR-7 灰鹭号", "CONTRACT #001 · GR-7 GREY HERON"],
	# hints (first time each)
	"hint_start": ["先别急着切。用 1 测量工具点外壳上的测压口和测点，看看这艘船现在的真实状态。", "Don't cut yet. Take tool 1 to the ports and test points on the hull — find out what this ship is really like now."],
	"hint_dead_leg": ["读数来自测压口实际连通的那一段。按 Tab 看图纸：P-C01 和货舱之间还有一个阀门 V-C01。", "A gauge reads whatever its port is connected to. Press Tab: there is a valve, V-C01, between P-C01 and the hold."],
	"hint_dead_leg_hose": ["V-C01 关着，软管只能抽到阀门外侧那一小段空管。", "With V-C01 shut the hose only reaches the empty stub outside the valve."],
	"hint_not_off": ["控制台显示的是指令，不是实测：母线仍然有电。", "The panel shows what was commanded, not what is true: the bus is still live."],
	"hint_remote": ["指令已发出。它真的停了吗？用测量工具去 E-D01 验证。", "Command sent. Did it actually stop? Verify at E-D01."],
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
	"hint_no_power": ["舱门电机没电。船坞辅助电源 PWR-EXT 在 D 舱顶部外侧。", "No power for the door motors. Dock aux socket PWR-EXT is on the roof above D."],
	"hint_hatch_jam": ["货舱门变形卡住了，先用 4 解除卡滞（HATCH-JAM）。", "The hatch is bent and jammed — clear HATCH-JAM with tool 4 first."],
	"hint_hose": ["软管在后台抽，不用守着。按 5 可以切换回收 / 排放。", "The hose works in the background. Press 5 again to switch recover / vent."],
	"hint_blowout": ["带压舱室被切开会爆发性失压：货物被推撞，气体收益也没了。", "Cutting into a pressurised room blows it out: cargo gets thrown and the gas is lost."],
	"hint_discharge_refused": ["发电机或蓄电池还在给母线供电，先断开 K-G 和 K-B。", "The generator or battery still feeds the bus — open K-G and K-B first."],
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
		zh = true
		return
	var cf := ConfigFile.new()
	if cf.load(CFG) == OK:
		zh = cf.get_value("ui", "zh", zh)
		hints = cf.get_value("ui", "hints", true)
		assist = cf.get_value("ui", "assist", true)


static func save_settings(testing: bool) -> void:
	if testing:
		return
	var cf := ConfigFile.new()
	cf.set_value("ui", "zh", zh)
	cf.set_value("ui", "hints", hints)
	cf.set_value("ui", "assist", assist)
	cf.save(CFG)
