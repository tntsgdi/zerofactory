# GR-7 "Grey Heron" as it is in the game (kept as the standard ruler), from ships/gr7.json.
import sys
sys.path.insert(0, '.')
from shipdraw import render, where
from sheet import sheet

S, OX, OY = 36.0, 150, 390
d, g = render('../../ships/gr7.json', S, OX, OY)
P = g.P
w = lambda t: where(d, t)
calls = []
top, bot = 160, 700
def call(n, tag, lx, row, kind, text, dx=0.0, dy=0.0):
    x, y = w(tag) if isinstance(tag, str) else tag
    calls.append((n, x + dx, y + dy, lx, top if row == 0 else bot, kind, text))
call(1, "CON-A", 120, 1, "sys", "驾驶控制台 CON-A（便签：剧情物件）")
call(2, "SEAT-P", 190, 1, "sys", "正副驾驶座 SEAT-P / SEAT-C（座椅外形，2 螺栓 + 滑轨锁）")
call(3, "OVH-A", 160, 0, "sys", "顶部开关面板 OVH-A")
call(4, "EM-A", 230, 0, "haz", "应急氧气柜 EM-A（带压小氧瓶，放气口 EM-A）")
call(5, "NAV-01", 300, 0, "energy", "导航电脑 NAV-01（后墙机架，自带 24 V 电池）")
call(6, "BB-01", 260, 1, "must", "黑匣子 BB-01（强制）在检修盖板 COV-A 后")
call(7, "TK-B1", 330, 1, "room", "氧 / 氮储气瓶 TK-B1 / TK-B2（1800 kPa）")
call(8, "ENV-B", 400, 1, "sys", "环控机 ENV-B")
call(9, "BUNK-B", 380, 0, "sys", "铺位 BUNK-B（明信片：剧情物件）")
call(10, "DR-BC", 470, 1, "room", "舱门 DR-AB / DR-BC（B→C 关着）")
call(11, "C-02", 640, 1, "sys", "货柜 C-01 / C-02 / C-03，每只 4 把锁（C-02 已滑脱倾斜）")
call(12, "RAIL-C", 600, 0, "struct", "货舱吊轨 RAIL-C + 吊钩 HOOK-1 / 2")
call(13, "HATCH-1", 720, 0, "room", "货舱顶门 HATCH-1 / 2（电机 HATCH-SW，卡滞 HATCH-JAM）")
call(14, "P-C01", 520, 0, "room", "测压口 P-C01 与阀门 V-C01 之间是死腔（测错阀门）")
call(15, "G-01", 860, 0, "must", "主电源 G-01（强制，燃料电池；远程停机失效，要本地手柄）")
call(16, "CAP-01", 940, 0, "energy", "蓄电池 B-01 / 电容 CAP-01 / 配电盘 SWB")
call(17, (30.3, -4.28), 1020, 0, "sys", "外部面板 CTRL-D：K-G、K-B、G-STOP、E-D01 测点、E-D02 放电")
call(18, "CP-E", 860, 1, "fluid", "冷却泵 CP-E + 冷却回路 q1–q4（q4 已破）")
call(19, "RAD", 960, 1, "fluid", "散热器 RAD（120 °C）")
call(20, (32.8, 1.5), 1040, 1, "room", "尾壁破口：E 舱一直通着真空")
call(21, "ENG-C", 1300, 1, "sys", "推进器 ENG-F / ENG-C / ENG-N")
call(22, "T-F01", 1200, 0, "haz", "推进剂罐 T-F01（护罩 GUARD-F 挡住回收口）")
call(23, "AUX-1", 1360, 0, "sys", "辅助单元 AUX-1 / AUX-2（挂在尾梁上）")
call(24, "K2", 760, 1, "struct", "龙骨 K1–K4（每 2.1 m 一颗螺栓接船壳）")
call(25, (15.8, 4.0), 560, 1, "struct", "船坞夹具 CL-01–04 夹着船底", dy=0.0)
zones = [(0.2, 4.9, 6.9, "A 驾驶段", "room"), (5.0, 10.0, 6.9, "B 乘员 / 生命维持", "room"), (10.0, 27.0, 6.9, "C 主货舱（有压）", "room"),
         (27.0, 33.0, 6.9, "D 电力舱 / E 维修舱", "room"), (33.0, 41.6, 6.9, "F 推进段（开放桁架）", "struct")]
sheet('gr7.html', 1800, 1110, 'GR-7「灰鹭」标准货运船 · 42 m · 结构图（现有，作为全游戏的标准尺子）',
      ['按游戏里的船型数据画出（ships/gr7.json，94 件零件 / 198 处固定）。用户 2026-10-16 定：保持现在的结构不重建。',
       '电、气、管、固定件四件套全部入门；第一章剧情物件都在原位。'], ''.join(g.o), P, calls, zones, legend_cols=2, scale_at=(0.0, -5.6))
print('ok')
