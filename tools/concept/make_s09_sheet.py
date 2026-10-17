# S-09 "Swift" from ships/s09.json (the build that will go into the game).
import sys
sys.path.insert(0, '.')
from shipdraw import render, where
from sheet import sheet

S, OX, OY = 58.0, 120, 430
d, g = render('../../ships/s09.json', S, OX, OY)
P = g.P
w = lambda t: where(d, t)
calls = []
top, bot = 150, 800
def call(n, tag, lx, row, kind, text, dx=0.0, dy=0.0):
    x, y = w(tag) if isinstance(tag, str) else tag
    calls.append((n, x + dx, y + dy, lx, top if row == 0 else bot, kind, text))
# 1 the pressure ball
call(1, "CON-S", 80, 0, "room", "上层：观察穹窗 + 主驾驶台 CON-S")
call(2, "SEAT-P", 150, 0, "sys", "主驾驶座 SEAT-P（螺栓 + 滑轨锁）")
call(3, "OVH-S", 220, 0, "sys", "顶部开关面板 OVH-S")
call(4, "SEAT-C", 80, 1, "sys", "下层：副驾驶座 SEAT-C")
call(5, "NAV-S", 150, 1, "energy", "导航终端 NAV-S（自带 24 V）")
call(6, "LOCK-2", 290, 0, "sys", "工具接口：工具柜 LOCK-1…4（挂在甲板下）")
call(7, "LADDER", 360, 0, "room", "梯井：甲板舱口 DR-AB + 梯子")
call(8, "LIFE-S", 220, 1, "fluid", "地板下：小型生命维持模块 LIFE-S")
call(9, "FDR-S", 290, 1, "must", "飞行记录仪 FDR-S（强制）：掀开地板 FL-2 才够得着")
call(10, (2.0, -3.0), 430, 0, "struct", "球壳：22 片弧面板焊成")
# 2 the transition neck
call(11, "DR-BL", 360, 1, "room", "过渡舱 L：内门 DR-BL（球舱 ↔ 气闸）")
call(12, "SUIT-1", 500, 0, "sys", "两套舱外服 SUIT-1 / 2（贵重）")
call(13, "SWB-S", 570, 0, "energy", "小配电箱 SWB-S（全船母线）")
call(14, "GLOVE-L", 640, 0, "sys", "维修手套口 GLOVE-L")
call(15, "HATCH-L", 430, 1, "room", "压力隔断门 HATCH-L：气闸 → 桁架（真空）")
call(16, "DOCK-S", 710, 0, "sys", "对接口 DOCK-S（顶部）")
call(17, "PWR-B", 500, 1, "energy", "电池 PWR-B（气闸内门旁）")
# 3 the truss
call(18, "FC-01", 780, 0, "haz", "燃料电池 FC-01 + 本地停机 FC-LOCAL")
call(19, "H2-T", 640, 1, "haz", "氢罐 H2-T / 氧罐 O2-T（托盘螺栓）")
call(20, "CAP-A", 850, 0, "energy", "机械臂电容组 CAP-A")
call(21, "CRATE-1", 780, 1, "sys", "小型货箱位 CRATE-1 / 2（精密备件，锁扣）")
call(22, "ARM-CTL", 920, 0, "energy", "机械臂控制基座 ARM-CTL（接母线）")
call(23, "ARM-01", 990, 0, "must", "机械臂 ARM-01（强制，1.6 t）：4 把发射锁折叠在导轨上")
call(24, (17.8, 2.17), 850, 1, "fluid", "外露燃料管 p3（尾部 → 球舱姿控），一切就漏")
call(25, (16.0, 0.12), 920, 1, "energy", "外露电缆：母线、制动器电缆沿桁架走")
call(26, (15.5, 0.9), 990, 1, "struct", "桁架细梁：弦杆 / 立柱 / 斜撑，节点螺栓")
call(27, "EXT-S", 1060, 1, "energy", "维修面板 EXT-S：K-FC、K-B、E-S01 测点、E-CAP 放电")
# 4 the tail
call(28, "BRK-P", 1060, 0, "haz", "制动器独立电源 BRK-P（K-BRK）：断总闸后机械臂仍抱死")
call(29, "RCS-T1", 1130, 0, "haz", "姿控推进剂球罐 RCS-T1 / T2")
call(30, "SPRAY-T", 1130, 1, "haz", "维修喷剂罐 SPRAY-T（带压）")
call(31, "MAIN-E", 1200, 1, "sys", "主推进器 MAIN-E（推力锥）")
call(32, "ATT-1", 1270, 0, "sys", "Y 型尾梁 + 双姿态喷嘴 ATT-1 / 2，散热片 RAD-1 / 2")
zones = [(0.05, 6.35, 5.6, "① 球形驾驶舱（双层，有压）", "room"), (6.35, 9.4, 5.6, "② 过渡舱 / 气闸（有压）", "room"),
         (9.4, 21.6, 5.6, "③ 桁架作业段（真空）", "struct"), (21.6, 26.0, 5.6, "④ 尾部推进段", "struct")]
sheet('s09_sheet.html', 1800, 1220, 'S-09「雨燕」维修穿梭机 · 26 m · 结构图（设计稿 v2，按用户规格）',
      ['游戏用的船型数据画出（ships/s09.json：113 件零件 / 198 处固定 / 15 条线路 / 17 个接口），审过即进游戏。',
       '小而精密：高价值部件多，粗拆很亏；从气闸进，不靠切；外露管线一切就断；桁架细梁误切会掉件。'], ''.join(g.o), P, calls, zones, legend_cols=2, scale_at=(0.0, -4.4))
print('ok')
