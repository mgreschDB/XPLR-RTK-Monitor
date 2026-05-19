#!/usr/bin/env python3
"""Generate app icon for XPLR RTK Monitor"""

from PIL import Image, ImageDraw, ImageFont
import math

SIZE = 1024
CENTER = SIZE // 2

img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background gradient (dark blue to black)
for y in range(SIZE):
    r = int(10 + (25 - 10) * (1 - y / SIZE))
    g = int(20 + (50 - 20) * (1 - y / SIZE))
    b = int(40 + (90 - 40) * (1 - y / SIZE))
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

# Rounded corners mask
mask = Image.new('L', (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
radius = int(SIZE * 0.22)
mask_draw.rounded_rectangle([(0, 0), (SIZE-1, SIZE-1)], radius=radius, fill=255)
img.putalpha(mask)

# Draw crosshair/target circles (representing precision)
# Outer ring - subtle
ring_color_outer = (60, 120, 180, 80)
draw.ellipse([CENTER-320, CENTER-320, CENTER+320, CENTER+320], outline=ring_color_outer, width=3)

# Middle ring
ring_color_mid = (80, 160, 220, 120)
draw.ellipse([CENTER-220, CENTER-220, CENTER+220, CENTER+220], outline=ring_color_mid, width=4)

# Inner ring - RTK accuracy ring (green = fixed)
ring_color_inner = (0, 220, 100, 200)
draw.ellipse([CENTER-120, CENTER-120, CENTER+120, CENTER+120], outline=ring_color_inner, width=6)

# Crosshair lines
line_color = (100, 180, 240, 150)
# Horizontal
draw.line([(CENTER-350, CENTER), (CENTER-140, CENTER)], fill=line_color, width=3)
draw.line([(CENTER+140, CENTER), (CENTER+350, CENTER)], fill=line_color, width=3)
# Vertical
draw.line([(CENTER, CENTER-350), (CENTER, CENTER-140)], fill=line_color, width=3)
draw.line([(CENTER, CENTER+140), (CENTER, CENTER+350)], fill=line_color, width=3)

# Center dot (position marker) - bright green
dot_radius = 28
draw.ellipse([CENTER-dot_radius, CENTER-dot_radius, CENTER+dot_radius, CENTER+dot_radius],
             fill=(0, 240, 80, 255))
# White border on dot
draw.ellipse([CENTER-dot_radius, CENTER-dot_radius, CENTER+dot_radius, CENTER+dot_radius],
             outline=(255, 255, 255, 200), width=4)

# Satellite arcs (top area)
arc_color = (100, 200, 255, 160)
draw.arc([CENTER-280, 80, CENTER+280, 400], start=200, end=340, fill=arc_color, width=4)
draw.arc([CENTER-200, 120, CENTER+200, 360], start=210, end=330, fill=arc_color, width=3)

# Small satellite dots
sat_positions = [
    (CENTER-180, 180), (CENTER+160, 200), (CENTER-60, 140),
    (CENTER+80, 160), (CENTER-120, 220)
]
for sx, sy in sat_positions:
    draw.ellipse([sx-6, sy-6, sx+6, sy+6], fill=(150, 220, 255, 200))

# Rail tracks at bottom (two parallel lines with cross ties)
rail_y = CENTER + 340
rail_width = 300
rail_left = CENTER - rail_width // 2
rail_right = CENTER + rail_width // 2
track_color = (180, 180, 180, 150)
tie_color = (140, 140, 140, 120)

# Rails
draw.line([(rail_left, rail_y-60), (rail_left, rail_y+100)], fill=track_color, width=5)
draw.line([(rail_right, rail_y-60), (rail_right, rail_y+100)], fill=track_color, width=5)

# Cross ties
for i in range(-2, 5):
    ty = rail_y + i * 30
    draw.line([(rail_left-20, ty), (rail_right+20, ty)], fill=tie_color, width=4)

# "RTK" text at bottom
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 80)
except:
    font = ImageFont.load_default()

# Draw RTK text
text = "RTK"
bbox = draw.textbbox((0, 0), text, font=font)
text_w = bbox[2] - bbox[0]
text_x = CENTER - text_w // 2
text_y = SIZE - 180
draw.text((text_x, text_y), text, fill=(0, 220, 100, 230), font=font)

# Save
output_path = "/Users/marcogresch/Documents/GitHub/XPLR-RTK-Monitor/AppIcon.png"
img.save(output_path, "PNG")
print(f"Icon saved: {output_path} ({SIZE}x{SIZE})")
