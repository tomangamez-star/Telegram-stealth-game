#!/usr/bin/env python3
"""Bake the stealth office into static PNG layers used by the web build."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SIZE = (1800, 1200)
OUT = Path(__file__).resolve().parents[1] / "assets/stealth"
WALLS = [
    (0, 0, 1800, 40), (0, 1160, 1800, 40), (0, 0, 40, 1200), (1760, 0, 40, 1200),
    (430, 40, 40, 320), (430, 500, 40, 660),
    (880, 40, 40, 220), (880, 400, 40, 420), (880, 960, 40, 200),
    (1330, 40, 40, 420), (1330, 600, 40, 560),
    (40, 580, 180, 40), (350, 580, 80, 40),
    (470, 580, 170, 40), (770, 580, 110, 40),
    (920, 580, 160, 40), (1210, 580, 120, 40),
    (1370, 580, 140, 40), (1640, 580, 120, 40),
]
TABLES = [(120,120,180,75),(560,150,190,78),(1010,690,190,80),(1460,130,180,78),(130,780,175,75),(560,930,190,78),(1460,760,170,78)]
LOCKERS = [(355,255),(790,1040),(1240,185),(1680,940)]

def rect(draw, values, fill, outline=None, width=1):
    x, y, w, h = values
    draw.rounded_rectangle((x, y, x+w, y+h), radius=8, fill=fill, outline=outline, width=width)

floor = Image.new("RGB", SIZE, "#121c25")
d = ImageDraw.Draw(floor)
rooms = [
    (40,40,390,540,"#1b2b35","ARCHIVE"),(470,40,410,540,"#202d38","SECURITY"),
    (920,40,410,540,"#1a2933","RECORDS"),(1370,40,390,540,"#202c35","OFFICE"),
    (40,620,390,540,"#202d35","LOUNGE"),(470,620,410,540,"#1b2933","SERVER"),
    (920,620,410,540,"#202b35","OPERATIONS"),(1370,620,390,540,"#192832","LOADING"),
]
font = ImageFont.load_default()
for x,y,w,h,color,name in rooms:
    d.rectangle((x,y,x+w,y+h), fill=color)
    d.text((x+18,y+18), name, font=font, fill="#536873")
    for tx in range(x+8, x+w, 64): d.line((tx,y,tx,y+h), fill="#243741", width=1)
    for ty in range(y+8, y+h, 64): d.line((x,ty,x+w,ty), fill="#243741", width=1)

# Door thresholds make the room connections readable at a glance.
doors = [(430,360,40,140),(880,260,40,140),(880,820,40,140),(1330,460,40,140),
         (220,580,130,40),(640,580,130,40),(1080,580,130,40),(1510,580,130,40)]
for x,y,w,h in doors:
    d.rectangle((x,y,x+w,y+h), fill="#344954")
    if w < h:
        d.line((x+5,y+7,x+w-5,y+7), fill="#76a0a8", width=3)
        d.line((x+5,y+h-7,x+w-5,y+h-7), fill="#172129", width=3)
    else:
        d.line((x+7,y+5,x+7,y+h-5), fill="#76a0a8", width=3)
        d.line((x+w-7,y+5,x+w-7,y+h-5), fill="#172129", width=3)

for x,y,w,h in WALLS:
    d.rectangle((x+9,y+10,x+w+9,y+h+10), fill="#081015")
    d.rectangle((x,y,x+w,y+h), fill="#52636d")
    d.rectangle((x+5,y+5,x+w-5,y+h-5), fill="#667b85")
    d.line((x+6,y+6,x+w-6,y+6), fill="#93a6ad", width=3)

for x,y,w,h in TABLES:
    d.rounded_rectangle((x+8,y+10,x+w+8,y+h+10), 10, fill="#0b1217")
    d.rounded_rectangle((x,y,x+w,y+h), 10, fill="#705949", outline="#9a7c62", width=3)
    d.line((x+18,y+18,x+w-18,y+18), fill="#b09272", width=2)
    for cx,cy in [(x+24,y-15),(x+w-24,y-15),(x+24,y+h+15),(x+w-24,y+h+15)]:
        d.ellipse((cx-12,cy-12,cx+12,cy+12), fill="#324550", outline="#627985")

# Details are baked once instead of redrawn in Godot.
for x,y in [(75,300),(500,330),(955,300),(1400,355),(350,1000),(840,730),(1280,1080),(1715,700)]:
    d.ellipse((x-18,y-18,x+18,y+18), fill="#233b32")
    d.ellipse((x-11,y-15,x+11,y+13), fill="#3b6a50")
    d.rectangle((x-12,y+12,x+12,y+29), fill="#604c3d")

for x,y in LOCKERS:
    d.rounded_rectangle((x-36,y-48,x+36,y+48), 6, fill="#293747", outline="#8391a3", width=3)
    d.line((x,y-45,x,y+45), fill="#101923", width=3)
    for dx in (-18,18):
        d.line((x+dx-8,y-24,x+dx+8,y-24), fill="#8ca0ad", width=2)
        d.ellipse((x+dx-3,y+7,x+dx+3,y+13), fill="#c2d0d7")

floor.save(OUT / "room_map.png", optimize=True)

# Foreground locker faces cover the character only after the player deliberately
# enters one. The rest stays transparent, so visibility never changes on bare floor.
cover = Image.new("RGBA", SIZE, (0,0,0,0))
c = ImageDraw.Draw(cover)
for x,y in LOCKERS:
    c.rounded_rectangle((x-38,y-24,x+38,y+52), 7, fill="#34465a", outline="#9bacc0", width=3)
    c.line((x,y-22,x,y+49), fill="#141e2a", width=3)
    c.line((x-34,y-17,x+34,y-17), fill="#64758a", width=2)
    c.ellipse((x-8,y+12,x-2,y+18), fill="#d6e0e6")
    c.ellipse((x+2,y+12,x+8,y+18), fill="#d6e0e6")
cover.save(OUT / "room_cover.png", optimize=True)
print("Baked room_map.png and room_cover.png")
