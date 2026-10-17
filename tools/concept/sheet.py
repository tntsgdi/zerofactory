# One design sheet: title, the drawing, segment bars under it, numbered
# callouts with a legend, a scale bar and the colour key. Pixel space.
from mini import BG, DIM, EQ, AIR, FLUID, HEAT, HAZ, VIO, HEAD, DEFS

KIND = {"room": AIR, "must": HEAT, "sys": EQ, "haz": HAZ, "struct": DIM, "energy": VIO, "fluid": FLUID}


def sheet(file, W, H, title, sub, body, P, calls, zones, legend_cols=2, legend_y=None, scale_at=None, scale_m=5, s=1.0, notes=None):
    """body: svg string (already in px); P(x, y) maps metres to px;
    calls: [(n, x, y, lx, ly, kind, text)]; zones: [(x0, x1, y_m, text, kind)]"""
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="N"><defs>{DEFS}</defs><rect width="{W}" height="{H}" fill="{BG}"/>', body]
    for x0, x1, y, t, k in zones:
        a, b = P(x0, y), P(x1, y)
        c = KIND.get(k, DIM)
        o.append(f'<line x1="{a[0] + 3:.0f}" y1="{a[1]:.0f}" x2="{b[0] - 3:.0f}" y2="{b[1]:.0f}" stroke="{c}" stroke-width="2"/>')
        o.append(f'<line x1="{a[0] + 3:.0f}" y1="{a[1] - 5:.0f}" x2="{a[0] + 3:.0f}" y2="{a[1] + 5:.0f}" stroke="{c}" stroke-width="1.5"/><line x1="{b[0] - 3:.0f}" y1="{b[1] - 5:.0f}" x2="{b[0] - 3:.0f}" y2="{b[1] + 5:.0f}" stroke="{c}" stroke-width="1.5"/>')
        o.append(f'<text x="{(a[0] + b[0]) / 2:.0f}" y="{a[1] + 20:.0f}" font-size="13" fill="{c}" text-anchor="middle">{t}</text>')
    for n, x, y, lx, ly, k, _ in calls:
        px, py = P(x, y)
        c = KIND.get(k, EQ)
        o.append(f'<line x1="{px:.0f}" y1="{py:.0f}" x2="{lx}" y2="{ly}" stroke="{c}" stroke-width="1" opacity="0.55"/><circle cx="{px:.0f}" cy="{py:.0f}" r="2.6" fill="{c}"/>')
        o.append(f'<circle cx="{lx}" cy="{ly}" r="11" fill="{BG}" stroke="{c}" stroke-width="1.4"/><text x="{lx}" y="{ly + 4}" font-size="12" fill="{c}" text-anchor="middle" font-weight="700">{n}</text>')
    o.append(f'<text x="40" y="50" font-size="24" fill="#e6ebf1" font-weight="700">{title}</text>')
    y = 78
    for line in (sub if isinstance(sub, list) else [sub]):
        o.append(f'<text x="40" y="{y}" font-size="14" fill="{DIM}">{line}</text>')
        y += 20
    # colour key, top right
    keys = [(AIR, "气体 / 有压舱"), (HEAT, "电缆 / 强制目标"), (VIO, "储能 / 弱电"), (FLUID, "冷却液 / 液体"), (HAZ, "危险品 / 锁扣"), ("#b4c0cf", "螺栓")]
    kx = W - 40 - 6 * 118
    for i, (c, t) in enumerate(keys):
        o.append(f'<rect x="{kx + i * 118}" y="38" width="12" height="12" fill="none" stroke="{c}" stroke-width="2"/><text x="{kx + i * 118 + 18}" y="49" font-size="12" fill="{DIM}">{t}</text>')
    if scale_at:
        a = P(scale_at[0], scale_at[1])
        b = P(scale_at[0] + scale_m, scale_at[1])
        o.append(f'<line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" stroke="{DIM}" stroke-width="2"/><text x="{b[0] + 8}" y="{b[1] + 4}" font-size="12" fill="{DIM}">{scale_m} m</text>')
    # legend
    ly0 = legend_y if legend_y else H - 30 - ((len(calls) + legend_cols - 1) // legend_cols) * 21
    cw = (W - 80) / legend_cols
    rows = (len(calls) + legend_cols - 1) // legend_cols
    for i, (n, x, y2, lx, ly, k, t) in enumerate(calls):
        col, row = i // rows, i % rows
        cx, cy = 40 + col * cw, ly0 + row * 21
        c = KIND.get(k, EQ)
        o.append(f'<circle cx="{cx + 9}" cy="{cy - 4}" r="9" fill="none" stroke="{c}" stroke-width="1.2"/><text x="{cx + 9}" y="{cy}" font-size="10" fill="{c}" text-anchor="middle" font-weight="700">{n}</text><text x="{cx + 26}" y="{cy + 1}" font-size="13" fill="#c3cad3">{t}</text>')
    if notes:
        nx, ny, lines = notes
        for i, t in enumerate(lines):
            o.append(f'<text x="{nx}" y="{ny + i * 19}" font-size="13" fill="{DIM}">{t}</text>')
    o.append('</svg>')
    open(file, 'w').write(HEAD + ''.join(o) + '</body></html>')
