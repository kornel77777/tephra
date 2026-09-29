import math

W = H = 1024
CX, CY = 512, 512

outline_spec = [
    (-18, 1.55),
    (42,  0.92),
    (100, 0.88),
    (155, 0.80),
    (210, 0.78),
    (275, 0.98),
]

base_r = 265
scale_y = 1.2

def to_xy(angle_deg, r_mult):
    a = math.radians(angle_deg - 90)
    r = base_r * r_mult
    return (CX + r * math.cos(a), CY + r * math.sin(a) * scale_y)

outer = [to_xy(a, r) for a, r in outline_spec]
apex_raw = (CX - 45, CY + 55)

# --- re-center the whole shape's bounding box on the canvas center ---
all_pts = outer + [apex_raw]
min_x = min(p[0] for p in all_pts)
max_x = max(p[0] for p in all_pts)
min_y = min(p[1] for p in all_pts)
max_y = max(p[1] for p in all_pts)
shape_cx = (min_x + max_x) / 2
shape_cy = (min_y + max_y) / 2
dx = CX - shape_cx
dy = CY - shape_cy

def shift(p):
    return (p[0] + dx, p[1] + dy)

outer = [shift(p) for p in outer]
apex = shift(apex_raw)

n = len(outer)

light_dir = (-0.55, -0.83)
def norm(v):
    m = math.hypot(*v)
    return (v[0] / m, v[1] / m) if m else (0, 0)
light_dir = norm(light_dir)

palette_steps = [
    (120, 132, 146),
    (78, 88, 100),
    (46, 52, 60),
    (26, 29, 34),
    (14, 16, 19),
]

def color_for(rank):
    return palette_steps[min(rank, len(palette_steps) - 1)]

def shrink(poly, amount=11):
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for x, y in poly:
        dxp, dyp = x - cx, y - cy
        d = math.hypot(dxp, dyp) or 1
        f = max(0, d - amount) / d
        out.append((cx + dxp * f, cy + dyp * f))
    return out

facet_dots = []
for i in range(n):
    a, b = outer[i], outer[(i + 1) % n]
    cx = (apex[0] + a[0] + b[0]) / 3 - CX
    cy = (apex[1] + a[1] + b[1]) / 3 - CY
    d = norm((cx, cy))
    dot = d[0] * light_dir[0] + d[1] * light_dir[1]
    facet_dots.append(dot)

order = sorted(range(n), key=lambda i: -facet_dots[i])
rank_of = {i: r for r, i in enumerate(order)}

# shadow sits under the shape's own (now centered) bottom edge
shape_bottom_y = max(p[1] for p in outer)

svg = []
svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
svg.append(f'''
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#15181e"/>
    <stop offset="0.55" stop-color="#0a0c10"/>
    <stop offset="1" stop-color="#030405"/>
  </linearGradient>
  <radialGradient id="glow" cx="0.5" cy="{shape_cy / H + dy / H:.3f}" r="0.62">
    <stop offset="0" stop-color="#2be0c8" stop-opacity="0.30"/>
    <stop offset="0.5" stop-color="#2be0c8" stop-opacity="0.08"/>
    <stop offset="1" stop-color="#2be0c8" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="shadow" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="#000000" stop-opacity="0.55"/>
    <stop offset="1" stop-color="#000000" stop-opacity="0"/>
  </radialGradient>
  <filter id="soft" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="16"/>
  </filter>
</defs>
''')

r = 224
svg.append(f'<rect width="{W}" height="{H}" rx="{r}" ry="{r}" fill="url(#bg)"/>')
svg.append(f'<rect width="{W}" height="{H}" rx="{r}" ry="{r}" fill="url(#glow)"/>')
svg.append(f'<ellipse cx="{CX}" cy="{shape_bottom_y + 25:.1f}" rx="200" ry="50" fill="url(#shadow)" filter="url(#soft)"/>')

for i in range(n):
    a, b = outer[i], outer[(i + 1) % n]
    tri = shrink([apex, a, b], amount=11)
    col = color_for(rank_of[i])
    hexcol = '#%02x%02x%02x' % col
    pts = " ".join(f"{p[0]:.1f},{p[1]:.1f}" for p in tri)
    svg.append(f'<polygon points="{pts}" fill="{hexcol}" stroke="#05070a" stroke-width="3"/>')

outline_pts = " ".join(f"{v[0]:.1f},{v[1]:.1f}" for v in outer)
svg.append(f'<polygon points="{outline_pts}" fill="none" stroke="#4be6d3" stroke-opacity="0.55" stroke-width="3"/>')

svg.append('</svg>')

import os
output_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'icon.svg')
with open(output_path, 'w') as f:
    f.write("\n".join(svg))

print("shape bbox center was", shape_cx, shape_cy, "-> shifted by", dx, dy)
