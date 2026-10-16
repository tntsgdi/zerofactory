import sys, random
sys.path.insert(0, '.')
import shipsvg as S

HEAD = '''<html><head><style>@font-face{font-family:N;src:url(file:///tmp/claude-0/fontsrc/NotoSansSC-VF.ttf)}
body{margin:0;background:#04070b;font-family:N}</style></head><body>'''

NEW = '#36e6ff'
OLD = '#9fb4cc'


def stars(w, h, n, seed=3):
    r = random.Random(seed)
    s = []
    for i in range(n):
        x, y = r.uniform(0, w), r.uniform(0, h)
        a = r.uniform(0.15, 0.8)
        s.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r.uniform(0.4, 1.3):.2f}" fill="#cfe6ff" opacity="{a:.2f}"/>')
    return ''.join(s)


def page(w, h, scale, ox, oy, calls, title, sub, legend_cols, file, legend_y=None, clip=None):
    body = S.draw_ship()
    g = f'<g transform="translate({ox},{oy}) scale({scale})">{body}</g>'
    if clip:
        g = f'<clipPath id="cl"><rect x="0" y="0" width="{clip}" height="{h}"/></clipPath><g clip-path="url(#cl)">{g}</g>'
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" font-family="N"><defs>{S.DEFS}</defs>',
             f'<rect width="{w}" height="{h}" fill="#04070b"/>', stars(w, h, 260),
             f'<ellipse cx="{w * 0.5}" cy="{oy}" rx="{w * 0.55}" ry="{h * 0.35}" fill="#0b2233" opacity="0.35" filter="url(#gp)"/>', g]
    # callouts
    for n, x, y, lx, ly, new in calls:
        px, py = ox + x * scale, oy + y * scale
        c = NEW if new else OLD
        parts.append(f'<line x1="{px}" y1="{py}" x2="{lx}" y2="{ly}" stroke="{c}" stroke-width="1" opacity="0.7"/>')
        parts.append(f'<circle cx="{px}" cy="{py}" r="3" fill="{c}"/>')
        parts.append(f'<circle cx="{lx}" cy="{ly}" r="12" fill="#04070b" stroke="{c}" stroke-width="1.5"/>')
        parts.append(f'<text x="{lx}" y="{ly + 4.5}" font-size="13" fill="{c}" text-anchor="middle" font-weight="700">{n}</text>')
    parts.append(f'<text x="40" y="52" font-size="26" fill="#e8f2ff" font-weight="700">{title}</text>')
    parts.append(f'<text x="40" y="80" font-size="14" fill="#7f97b3">{sub}</text>')
    parts.append(f'<circle cx="{w - 330}" cy="46" r="6" fill="{NEW}"/><text x="{w - 318}" y="51" font-size="13" fill="#9fb4cc">新增、可拆的零件</text>')
    parts.append(f'<circle cx="{w - 190}" cy="46" r="6" fill="{OLD}"/><text x="{w - 178}" y="51" font-size="13" fill="#9fb4cc">原有零件（换新外观）</text>')
    # legend
    ly0 = legend_y if legend_y else h - 30 - max(len(c) for c in legend_cols) * 22
    cw = (w - 80) / len(legend_cols)
    for ci, col in enumerate(legend_cols):
        for ri, (n, txt, new) in enumerate(col):
            x = 40 + ci * cw
            y = ly0 + ri * 22
            c = NEW if new else OLD
            parts.append(f'<circle cx="{x + 9}" cy="{y - 4}" r="9" fill="none" stroke="{c}" stroke-width="1.2"/><text x="{x + 9}" y="{y}" font-size="11" fill="{c}" text-anchor="middle" font-weight="700">{n}</text>')
            parts.append(f'<text x="{x + 26}" y="{y + 1}" font-size="13" fill="#c9d6e6">{txt}</text>')
    parts.append('</svg>')
    open(file, 'w').write(HEAD + ''.join(parts) + '</body></html>')


# ---- 1: the whole ship
SC = 34
OX, OY = 120, 330
calls = [
    (1, 3.6, 1.3, 150, 150, True), (2, 1.9, 1.5, 70, 200, False), (3, 3.55, -3.15, 260, 150, True), (4, 4.35, -2.1, 330, 150, True),
    (5, 6.4, -2.7, 400, 150, True), (6, 5.9, -0.6, 470, 150, True), (7, 9.0, -1.0, 540, 150, True), (8, 6.3, 2.0, 600, 540, False),
    (9, 17.05, -2.9, 700, 150, True), (10, 17.0, 1.7, 700, 540, False), (11, 15.6, 2.85, 800, 540, False), (12, 25.9, -0.9, 900, 150, True),
    (13, 18.85, -1.5, 800, 150, False), (14, 28.65, -1.7, 1000, 150, False), (15, 31.4, -0.8, 1080, 150, False), (16, 30.3, 0.6, 1050, 540, False),
    (17, 28.7, -4.8, 1150, 150, True), (18, 31.6, 4.3, 1150, 540, True), (19, 3.55, -4.6, 200, 120, True), (20, 24.6, -5.0, 900, 110, True),
    (21, 36.3, 0.0, 1350, 540, False), (22, 35.6, -2.15, 1350, 150, False), (23, 18.35, -3.85, 760, 110, False), (24, 15.0, -3.3, 620, 110, False), (25, 24.0, 1.6, 900, 540, True),
]
cols = [
    [(1, '驾驶座 SEAT-P（抗荷座椅 + 束带，2 螺栓）', True), (2, '全息飞控台 CON-A（断电后投影熄灭）', False), (3, '顶部开关面板 OVH-A', True),
     (4, '应急氧气柜 EM-A（小气瓶，切了会爆）', True), (5, '睡眠舱 SLEEP-1 / 2（带灯、接 B 舱电）', True), (6, '储物柜 LOCK-B1…3（小件，可能有货）', True)],
    [(7, '食物打印机 GAL-B（接水管，断水再拆）', True), (8, '氧 / 氮储罐 TK-B1 / B2 + 环控 ENV-B', False), (9, '货舱吊车小车 CRANE-T（自带锁 + 电机）', True),
     (10, '货柜 C-01…03 + 磁浮托架（发光 = 托架通电）', False), (11, '磁力货锁（灯亮 = 锁着）', False), (12, '货舱管理终端 CARGO-T', True)],
    [(13, '舱壁肋骨（减重孔，结构件）', False), (14, '主电源 G-01：紧凑聚变堆（环亮 = 运行）', False), (15, '电池 / 电容组 / 配电盘', False),
     (16, '冷却泵 + 冷却回路（发光 = 有压）', False), (17, '外置散热片 RAD-F1 / F2', True), (18, '姿控喷嘴组 RCS-1…4（残留推进剂）', True)],
    [(19, '传感器罩 SENS-1', True), (20, '通讯天线 ANT-1', True), (21, '等离子推进器：磁约束喷管', False), (22, '推进剂罐 T-F01', False),
     (23, '货舱顶门：力场密封', False), (24, '船体发光带 / 电缆槽（断电即熄）', False)],
    [(25, '货盘 PAL-C（6 个小货箱 + 绑带）', True)],
]
page(1600, 760, SC, OX, OY, calls, 'GR-7「灰鹭」级货船 · 科幻改版内饰（设计稿）', '侧剖面，42 m。青色 = 通电 / 运行中，熄灭 = 已断电；橙 = 热 / 危险；绿 = 流体；蓝 = 气体；紫 = 高能', cols, 'ship_full.html', legend_y=600)

# ---- 2: cockpit and crew deck close-up
SC2 = 92
calls2 = [
    (1, 3.6, 1.3, 520, 830, True), (2, 1.9, 1.6, 120, 830, False), (3, 3.55, -3.15, 470, 140, True), (4, 4.35, -2.1, 640, 170, True),
    (5, 6.4, -2.7, 820, 140, True), (6, 5.9, -0.6, 680, 520, True), (7, 9.0, -1.0, 1100, 520, True), (8, 6.3, 2.0, 760, 830, False),
    (19, 3.55, -4.65, 330, 140, True), (25, 1.8, -2.4, 120, 170, False), (26, 4.25, 2.75, 600, 850, False), (27, 4.35, -0.7, 640, 470, False),
]
cols2 = [
    [(1, '正副驾驶座：2 螺栓 + 束带锁扣', True), (2, '全息飞控台：通电才有投影', False), (3, '顶部开关面板：总电闸在这里', True)],
    [(4, '应急氧气柜：带压气瓶，走危险品口', True), (5, '睡眠舱：舱灯接 B 舱电，先断电', True), (6, '储物柜：三格小件，五爪钩一次抓走', True)],
    [(7, '食物打印机：接水管，先关阀再拆', True), (8, '氧 / 氮储罐 + 环控机（原有）', False), (19, '船外传感器罩（玻璃件，易碎）', True)],
    [(25, '观察窗（原有，加 HUD 刻线）', False), (26, '黑匣子在地板盖板下（原有）', False), (27, '导航计算机 NAV-01 改成竖装机架（原有）', False)],
]
page(1600, 980, SC2 - 6, 140, 480, calls2, '驾驶舱与乘员舱 · 特写（设计稿）', 'A 舱（驾驶）+ B 舱（乘员 / 生命维持），船头 0–10 m', cols2, 'ship_close.html', legend_y=890, clip=1600)
print('ok')
