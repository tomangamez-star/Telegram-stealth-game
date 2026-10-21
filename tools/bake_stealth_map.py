#!/usr/bin/env python3
"""Bake the mobile stealth floor and custom startup art into PNG files."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1] / "assets/stealth"
OUT.mkdir(parents=True, exist_ok=True)
SIZE = (1600, 1200)
WALLS = [
    (0,0,1600,40),(0,1160,1600,40),(0,0,40,1200),(1560,0,40,1200),
    (620,40,40,80),(620,220,40,200),(620,520,40,200),(620,820,40,200),(620,1120,40,40),
    (940,40,40,80),(940,220,40,200),(940,520,40,200),(940,820,40,200),(940,1120,40,40),
    (40,290,580,30),(980,290,580,30),(40,590,580,30),(980,590,580,30),
    (40,890,580,30),(980,890,580,30),
]
FURNITURE = [(75,75,175,52),(1350,75,175,52),(75,1050,175,52),(1350,1050,175,52)]

floor = Image.new("RGB", SIZE, "#111b23")
d = ImageDraw.Draw(floor)
font = ImageFont.load_default()
room_names = ["ARCHIVE","SECURITY","RECORDS","UTILITY","OFFICE","CONTROL","EVIDENCE","STORAGE"]
for row in range(4):
    y = 40 + row * 300
    for side, x in enumerate((40, 980)):
        color = "#1a2a34" if (row + side) % 2 == 0 else "#1d2d37"
        d.rectangle((x,y,x+580,y+250), fill=color)
        for tx in range(x, x+581, 64): d.line((tx,y,tx,y+250), fill="#243945")
        for ty in range(y, y+251, 64): d.line((x,ty,x+580,ty), fill="#243945")
        d.text((x+18,y+18), room_names[row*2+side], font=font, fill="#617985")

# Central hallway is visually distinct and uncluttered.
d.rectangle((660,40,940,1160), fill="#263944")
for y in range(60,1160,80):
    d.line((685,y,915,y), fill="#2f4854", width=2)
d.line((800,40,800,1160), fill="#38515c", width=2)
d.text((752,55), "CENTRAL HALL", font=font, fill="#74909a")

# Door thresholds align exactly with the breaks in both hallway walls.
for y in (120,420,720,1020):
    for x in (620,940):
        d.rectangle((x,y,x+40,y+100), fill="#3b535e")
        d.line((x+5,y+8,x+35,y+8), fill="#88a5ad", width=3)
        d.line((x+5,y+92,x+35,y+92), fill="#17232a", width=3)

# Extraction door at the far end of the hallway.
d.rectangle((740,0,860,42), fill="#214b43")
d.line((748,37,852,37), fill="#8ff1d1", width=5)
d.polygon([(800,12),(782,30),(792,30),(792,50),(808,50),(808,30),(818,30)], fill="#8ff1d1")
d.text((778,58), "EXIT", font=font, fill="#8ff1d1")

for x,y,w,h in WALLS:
    d.rectangle((x+7,y+8,x+w+7,y+h+8), fill="#070d11")
    d.rectangle((x,y,x+w,y+h), fill="#5b707a")
    d.rectangle((x+5,y+5,x+w-5,y+h-5), fill="#718690")
    d.line((x+6,y+6,x+w-6,y+6), fill="#a2b2b8", width=2)

# Four slim cabinets, flush against outer walls; no loose tables or chairs.
for x,y,w,h in FURNITURE:
    d.rounded_rectangle((x+6,y+7,x+w+6,y+h+7), 5, fill="#091116")
    d.rounded_rectangle((x,y,x+w,y+h), 5, fill="#344651", outline="#82949d", width=3)
    for dx in range(x+30,x+w,45):
        d.line((dx,y+9,dx,y+h-9), fill="#1b2931", width=2)
        d.ellipse((dx+10,y+h/2-2,dx+14,y+h/2+2), fill="#b8c8cd")

# Sparse wall-side props are visual only and never obstruct navigation.
for x,y in [(85,250),(1515,250),(85,550),(1515,850)]:
    d.ellipse((x-17,y-17,x+17,y+17), fill="#254236")
    d.ellipse((x-10,y-14,x+10,y+12), fill="#477a5c")
    d.rectangle((x-11,y+10,x+11,y+27), fill="#695141")

floor.save(OUT / "room_map.png", optimize=True)

# Engine boot splash: replaces the default Godot branding.
boot = Image.new("RGB", (1280,720), "#071017")
b = ImageDraw.Draw(boot)
for radius, color in [(185,"#0b1f28"),(125,"#10313a"),(70,"#174a4d")]:
    b.ellipse((640-radius,315-radius,640+radius,315+radius), fill=color)
try:
    title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 54)
    small_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
except OSError:
    title_font = small_font = font
title = "DOODLE / COVERT"
box = b.textbbox((0,0), title, font=title_font)
b.text(((1280-(box[2]-box[0]))/2,535), title, font=title_font, fill="#91f1d0")
subtitle = "PREPARING THE MISSION"
box = b.textbbox((0,0), subtitle, font=small_font)
b.text(((1280-(box[2]-box[0]))/2,610), subtitle, font=small_font, fill="#78949e")
# Simple top-down loader matching the actual in-game doodle silhouette.
doodle = Image.new("RGBA", (128,150), (0,0,0,0))
dd = ImageDraw.Draw(doodle)
dd.ellipse((35,76,93,134), fill="#17232a", outline="#071015", width=5)  # body
dd.ellipse((21,83,43,111), fill="#dda077", outline="#15171b", width=4)  # left hand
dd.ellipse((85,83,107,111), fill="#dda077", outline="#15171b", width=4) # right hand
dd.ellipse((40,121,61,148), fill="#111820", outline="#060a0d", width=4)
dd.ellipse((67,121,88,148), fill="#111820", outline="#060a0d", width=4)
dd.ellipse((18,10,110,106), fill="#111318", outline="#dda077", width=5) # head/hair
for x,y,r in [(39,24,17),(61,15,19),(82,24,18),(30,46,18),(55,39,22),(82,45,21),(51,62,23),(76,65,22)]:
    dd.ellipse((x-r,y-r,x+r,y+r), fill="#17191e")
dd.arc((21,13,107,104), 195, 345, fill="#353842", width=4)
doodle.save(OUT / "loading_doodle.png", optimize=True)
boot.paste(doodle, (640-doodle.width//2, 315-doodle.height//2), doodle)

boot.save(OUT / "boot_splash.png", optimize=True)

print("Baked room_map.png, boot_splash.png and loading_doodle.png")
