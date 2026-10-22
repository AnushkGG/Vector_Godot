import os
from PIL import Image, ImageDraw

assets_dir = r"c:\Users\ANANYA KOMARWAR\Downloads\vector\GodotVector\assets"

def save(img, name):
    img.save(os.path.join(assets_dir, name))
    print(f"  {name}")

# -------------------------------------------------------
# 1. WATER TANK (barrel on lattice legs)
# -------------------------------------------------------
w, h = 50, 80
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Lattice legs
d.rectangle([3, 50, 7, 80], fill='black')
d.rectangle([43, 50, 47, 80], fill='black')
d.line([7, 50, 43, 80], fill='black', width=2)
d.line([43, 50, 7, 80], fill='black', width=2)
d.line([3, 65, 47, 65], fill='black', width=2)  # cross brace
# Platform under barrel
d.rectangle([0, 46, 50, 52], fill='black')
# Barrel body
d.polygon([(4,10),(46,10),(50,18),(0,18)], fill='black')  # cap
d.rectangle([0, 17, 50, 48], fill='black')  # body
# Hoop lines
d.line([0,26,50,26], fill=(50,50,50,255), width=1)
d.line([0,37,50,37], fill=(50,50,50,255), width=1)
# Stave lines
d.line([12,10,12,46], fill=(50,50,50,255))
d.line([25,10,25,46], fill=(50,50,50,255))
d.line([38,10,38,46], fill=(50,50,50,255))
# Vent pipe on top
d.rectangle([22,0,28,10], fill='black')
d.rectangle([18,0,32,3], fill='black')  # pipe cap
save(img, "obs_watertank.png")

# -------------------------------------------------------
# 2. CRANE ARM (horizontal boom with cable and hook)
# -------------------------------------------------------
w, h = 120, 90
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Vertical mast
d.rectangle([0, 0, 10, 90], fill='black')
d.rectangle([4, 0, 6, 90], fill=(40,40,40,255))  # seam
# Horizontal boom
d.polygon([(10,5),(120,20),(120,26),(10,14)], fill='black')
# Support cable from mast top to boom tip
d.line([5, 0, 120, 20], fill='black', width=3)
# Hanging cable
d.line([90, 22, 90, 70], fill='black', width=2)
# Hook
d.arc([82, 64, 98, 80], 0, 180, fill='black', width=4)
d.line([90, 64, 90, 56], fill='black', width=2)
# Yellow/black hazard stripes on boom (as shadow - just dark lines)
for i in range(0, 6):
    xi = 20 + i * 16
    d.line([xi, 8, xi+8, 24], fill=(30,30,30,255), width=2)
save(img, "obs_crane.png")

# -------------------------------------------------------
# 3. LADDER (vertical rungs)
# -------------------------------------------------------
w, h = 30, 90
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Side rails
d.rectangle([2, 0, 8, 90], fill='black')
d.rectangle([22, 0, 28, 90], fill='black')
# Rungs
for y in range(8, 90, 14):
    d.rectangle([8, y, 22, y+5], fill='black')
save(img, "obs_ladder.png")

# -------------------------------------------------------
# 4. SATELLITE DISH on pole
# -------------------------------------------------------
w, h = 55, 70
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Pole
d.rectangle([25, 35, 30, 70], fill='black')
# Dish (filled arc shape)
d.pieslice([0, 10, 50, 60], start=200, end=340, fill='black')
# Support arm from pole to dish center
d.line([27, 35, 25, 35], fill='black', width=3)
# Feed horn (small rectangle at focus)
d.rectangle([20, 28, 28, 35], fill='black')
d.line([24, 20, 24, 28], fill='black', width=3)
save(img, "obs_satellite.png")

# -------------------------------------------------------
# 5. VENT / AC UNIT (wide box with fan grilles)
# -------------------------------------------------------
w, h = 70, 45
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Main box
d.rectangle([0, 0, 70, 45], fill='black')
# Top fin
d.rectangle([5, 0, 65, 5], fill='black')
# Fan grill slats (dark grey lines on black)
for i in range(6):
    d.line([8+i*9, 8, 8+i*9, 38], fill=(55,55,55,255), width=2)
# Outlet duct on right
d.rectangle([62, 12, 70, 32], fill=(30,30,30,255))
# Bolt/rivet dots
for bx in [4, 66]:
    for by in [4, 40]:
        d.ellipse([bx-2,by-2,bx+2,by+2], fill=(40,40,40,255))
save(img, "obs_vent.png")

# -------------------------------------------------------
# 6. POWER LINE POLE with cables
# -------------------------------------------------------
w, h = 60, 90
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Main pole
d.rectangle([27, 0, 33, 90], fill='black')
# Cross arm at top
d.rectangle([5, 10, 55, 16], fill='black')
# Insulators
for ix in [10, 30, 50]:
    d.ellipse([ix-4, 6, ix+4, 14], fill='black')
    d.ellipse([ix-4, 14, ix+4, 22], fill='black')
# Cable sag to left and right (simulate going off-image)
d.line([10, 10, 0, 25], fill='black', width=2)
d.line([50, 10, 60, 25], fill='black', width=2)
d.line([30, 13, 0, 30], fill='black', width=2)
d.line([30, 13, 60, 30], fill='black', width=2)
# Ground brace
d.line([27, 80, 10, 90], fill='black', width=3)
d.line([33, 80, 50, 90], fill='black', width=3)
save(img, "obs_pole.png")

# -------------------------------------------------------
# 7. ARCHWAY / LOW CONCRETE BEAM (must slide under)
# -------------------------------------------------------
w, h = 160, 50
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Left pillar
d.rectangle([0, 0, 18, 50], fill='black')
# Right pillar
d.rectangle([142, 0, 160, 50], fill='black')
# Top beam
d.rectangle([0, 0, 160, 18], fill='black')
# Rebar marks
for rx in range(20, 140, 18):
    d.line([rx, 4, rx, 14], fill=(50,50,50,255), width=2)
save(img, "obs_arch.png")

# -------------------------------------------------------
# 8. BILLBOARD FRAME (jump over or run under)
# -------------------------------------------------------
w, h = 80, 70
img = Image.new('RGBA', (w, h), (0,0,0,0))
d = ImageDraw.Draw(img)
# Two support legs
d.rectangle([10, 35, 16, 70], fill='black')
d.rectangle([64, 35, 70, 70], fill='black')
# Billboard face
d.rectangle([0, 0, 80, 38], fill='black')
# Dark text lines (shadow design detail)
d.line([8, 10, 72, 10], fill=(50,50,50,255), width=3)
d.line([8, 20, 55, 20], fill=(50,50,50,255), width=3)
d.line([8, 30, 65, 30], fill=(50,50,50,255), width=3)
# Frame border
d.rectangle([0,0,80,38], outline=(40,40,40,255), width=2)
save(img, "obs_billboard.png")

print("\nAll 8 new obstacles generated!")
