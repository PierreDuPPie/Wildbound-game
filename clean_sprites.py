import os
import glob
from PIL import Image

def process_creature(img_path, crop_box, out_paths):
    img = Image.open(img_path).convert("RGBA")
    cropped = img.crop(crop_box)
    
    # Sample background color from corner of crop box
    bg_color = cropped.getpixel((5, 5))
    
    data = cropped.getdata()
    new_data = []
    tolerance = 65
    for item in data:
        dist = abs(item[0]-bg_color[0]) + abs(item[1]-bg_color[1]) + abs(item[2]-bg_color[2])
        if dist < tolerance:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    cropped.putdata(new_data)
    
    # Trim transparency
    bbox = cropped.getbbox()
    if bbox:
        cropped = cropped.crop(bbox)
        
    # Scale nicely into 128x128 canvas
    canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    cropped.thumbnail((116, 116), Image.Resampling.LANCZOS)
    
    # Align to bottom-center of 128x128 box for ground alignment
    x_offset = (128 - cropped.width) // 2
    y_offset = 124 - cropped.height
    canvas.paste(cropped, (x_offset, y_offset), cropped)
    
    for path in out_paths:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        canvas.save(path, "PNG")
        print(f"Saved clean sprite to {path}")

brain_dir = "C:/Users/pierr/.gemini/antigravity/brain/2a0fb6bc-718f-4333-ab82-a0a50c6751b8"

targets = [
    ("ratelit", "ratelit_production*.jpg", (50, 50, 480, 420)),
    ("meerkit", "meerkit_concept*.jpg", (80, 150, 420, 560)),
    ("pangolet", "pangolet_concept*.jpg", (100, 150, 480, 540))
]

dirs = [
    "c:/Users/pierr/OneDrive/wildbound game/unzipped/wildbound_mvp/assets/sprites/creatures",
    "c:/Users/pierr/OneDrive/wildbound game/WILDBOUND_v0.2.0-dev/assets/sprites/creatures"
]

for species_id, pattern, crop_box in targets:
    files = glob.glob(f"{brain_dir}/{pattern}")
    if files:
        out_paths = [f"{d}/{species_id}/battle_idle.png" for d in dirs]
        process_creature(files[0], crop_box, out_paths)

print("Finished precise sprite extraction!")
