#!/usr/bin/env python3
"""Generate side-view car and train marker images for the RTK Monitor app"""

from PIL import Image, ImageDraw
import json, os

SIZE = 128

def generate_car(filename):
    """Side view car"""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = SIZE // 2, SIZE // 2 + 10
    
    # Car body
    body_x1, body_y1 = 18, cy - 16
    body_x2, body_y2 = 110, cy + 12
    
    # Shadow
    draw.rounded_rectangle([body_x1+2, body_y1+4, body_x2+2, body_y2+4], radius=8, fill=(0, 0, 0, 50))
    
    # Body
    draw.rounded_rectangle([body_x1, body_y1, body_x2, body_y2], radius=8, fill=(50, 55, 60, 255))
    
    # Roof / cabin (trapezoid shape)
    roof_pts = [
        (38, body_y1),      # left bottom of roof
        (46, body_y1 - 22), # left top
        (88, body_y1 - 22), # right top
        (98, body_y1),      # right bottom
    ]
    draw.polygon(roof_pts, fill=(60, 65, 70, 255))
    
    # Windows
    draw.rounded_rectangle([48, body_y1 - 20, 66, body_y1 - 4], radius=3, fill=(140, 210, 255, 230))
    draw.rounded_rectangle([70, body_y1 - 20, 86, body_y1 - 4], radius=3, fill=(140, 210, 255, 230))
    
    # Wheels
    wheel_y = body_y2 - 2
    wheel_r = 10
    # Front wheel
    draw.ellipse([30-wheel_r, wheel_y-wheel_r, 30+wheel_r, wheel_y+wheel_r], fill=(30, 30, 30, 255))
    draw.ellipse([30-6, wheel_y-6, 30+6, wheel_y+6], fill=(80, 80, 80, 255))
    # Rear wheel
    draw.ellipse([90-wheel_r, wheel_y-wheel_r, 90+wheel_r, wheel_y+wheel_r], fill=(30, 30, 30, 255))
    draw.ellipse([90-6, wheel_y-6, 90+6, wheel_y+6], fill=(80, 80, 80, 255))
    
    # Headlight
    draw.ellipse([104, cy-6, 112, cy+2], fill=(255, 240, 150, 230))
    
    # Tail light
    draw.ellipse([18, cy-4, 24, cy+2], fill=(255, 50, 50, 200))
    
    img.save(filename, "PNG")
    print(f"Car marker saved: {filename}")


def generate_train(filename):
    """Side view train (DB style)"""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = SIZE // 2, SIZE // 2 + 8
    
    # Train body
    body_x1, body_y1 = 10, cy - 22
    body_x2, body_y2 = 118, cy + 10
    
    # Shadow
    draw.rounded_rectangle([body_x1+2, body_y1+3, body_x2+2, body_y2+3], radius=6, fill=(0, 0, 0, 50))
    
    # Body (DB red)
    draw.rounded_rectangle([body_x1, body_y1, body_x2, body_y2], radius=6, fill=(200, 30, 40, 255))
    
    # White stripe
    stripe_y = cy - 2
    draw.rectangle([body_x1+2, stripe_y, body_x2-2, stripe_y+5], fill=(255, 255, 255, 220))
    
    # Windows (row)
    win_y1 = body_y1 + 6
    win_y2 = body_y1 + 20
    for wx in range(22, 108, 18):
        draw.rounded_rectangle([wx, win_y1, wx+12, win_y2], radius=2, fill=(140, 210, 255, 230))
    
    # Front cab (rounded nose)
    draw.rounded_rectangle([108, body_y1+2, 118, body_y2-2], radius=5, fill=(180, 25, 35, 255))
    draw.rounded_rectangle([110, win_y1, 116, win_y2], radius=3, fill=(100, 180, 240, 230))
    
    # Headlight
    draw.ellipse([113, cy-2, 119, cy+4], fill=(255, 240, 150, 240))
    
    # Wheels / bogies
    wheel_y = body_y2
    wheel_r = 7
    for wx in [28, 40, 85, 97]:
        draw.ellipse([wx-wheel_r, wheel_y-wheel_r+2, wx+wheel_r, wheel_y+wheel_r+2], fill=(40, 40, 40, 255))
        draw.ellipse([wx-4, wheel_y-2, wx+4, wheel_y+4], fill=(90, 90, 90, 255))
    
    # Bogie frames
    draw.rectangle([22, wheel_y-2, 46, wheel_y+1], fill=(60, 60, 60, 200))
    draw.rectangle([79, wheel_y-2, 103, wheel_y+1], fill=(60, 60, 60, 200))
    
    # Pantograph on roof
    panto_x = 60
    draw.line([(panto_x, body_y1), (panto_x, body_y1-10)], fill=(60, 60, 60, 200), width=2)
    draw.line([(panto_x-8, body_y1-10), (panto_x+8, body_y1-10)], fill=(60, 60, 60, 200), width=2)
    draw.line([(panto_x-5, body_y1-10), (panto_x, body_y1-18)], fill=(60, 60, 60, 200), width=2)
    draw.line([(panto_x+5, body_y1-10), (panto_x, body_y1-18)], fill=(60, 60, 60, 200), width=2)
    draw.line([(panto_x-6, body_y1-18), (panto_x+6, body_y1-18)], fill=(40, 40, 40, 255), width=3)
    
    img.save(filename, "PNG")
    print(f"Train marker saved: {filename}")


def generate_crosshair(filename):
    """Crosshair/scope marker"""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx, cy = SIZE // 2, SIZE // 2
    r = 30
    
    # Outer ring
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(0, 150, 255, 230), width=4)
    
    # Crosshair lines
    gap = 10
    line_len = 20
    lw = 3
    draw.line([(cx, cy-r-line_len), (cx, cy-gap)], fill=(0, 150, 255, 230), width=lw)
    draw.line([(cx, cy+gap), (cx, cy+r+line_len)], fill=(0, 150, 255, 230), width=lw)
    draw.line([(cx-r-line_len, cy), (cx-gap, cy)], fill=(0, 150, 255, 230), width=lw)
    draw.line([(cx+gap, cy), (cx+r+line_len, cy)], fill=(0, 150, 255, 230), width=lw)
    
    # Center dot
    draw.ellipse([cx-5, cy-5, cx+5, cy+5], fill=(0, 200, 100, 255))
    
    img.save(filename, "PNG")
    print(f"Crosshair marker saved: {filename}")


# Generate all markers
output_dir = "/Users/marcogresch/Documents/GitHub/XPLR-RTK-Monitor/XPLR-RTK-Monitor/Assets.xcassets"

for name in ["marker_car.imageset", "marker_train.imageset", "marker_crosshair.imageset"]:
    os.makedirs(f"{output_dir}/{name}", exist_ok=True)

generate_car(f"{output_dir}/marker_car.imageset/marker_car.png")
generate_train(f"{output_dir}/marker_train.imageset/marker_train.png")
generate_crosshair(f"{output_dir}/marker_crosshair.imageset/marker_crosshair.png")

for name in ["marker_car", "marker_train", "marker_crosshair"]:
    contents = {
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1}
    }
    with open(f"{output_dir}/{name}.imageset/Contents.json", "w") as f:
        json.dump(contents, f, indent=2)

print("All side-view markers generated!")
