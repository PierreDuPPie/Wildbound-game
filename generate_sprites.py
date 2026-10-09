import os
import glob
from PIL import Image, ImageDraw, ImageFilter

base_dir = "c:/Users/pierr/OneDrive/wildbound game/unzipped/wildbound_mvp/assets/sprites/creatures"

creatures = {
    "ratelit": "#24282a", "meerkit": "#d9ad62", "pangolet": "#b89162",
    "aardvark": "#8B5A2B", "lionet": "#CDAA7D", "cheetan": "#EED8AE", 
    "elephunt": "#8B8682", "rhinorex": "#708090", "hippotam": "#4A4A4A", 
    "zebrafly": "#F0F8FF", "giraffid": "#DAA520", "crocodyl": "#556B2F", 
    "ostrichy": "#D2B48C", "hyenox": "#8B7355", "warthusk": "#8B6914", 
    "baboonic": "#8B7D6B", "gorilox": "#1C1C1C", "chimpaz": "#363636", 
    "leopaws": "#FF8C00", "buffalox": "#3D3D3D", "jackalin": "#CDBA96", 
    "vulturon": "#000000", "pythonis": "#6B8E23", "mambara": "#228B22", 
    "monitorz": "#5C4033", "servalyn": "#FFD700", "caraclaw": "#CD853F", 
    "gazellor": "#F4A460", "springer": "#D2691E", "wildebot": "#4F4F4F"
}

def remove_bg_and_crop(img_path, out_path):
    try:
        img = Image.open(img_path).convert("RGBA")
        width, height = img.size
        # Crop the left third of the image (assuming front view is there)
        box = (0, 0, int(width/3), height)
        img = img.crop(box)
        
        # Simple chroma key: assume top-left pixel is background
        bg_color = img.getpixel((5, 5))
        
        data = img.getdata()
        new_data = []
        tolerance = 40
        for item in data:
            if abs(item[0]-bg_color[0]) < tolerance and \
               abs(item[1]-bg_color[1]) < tolerance and \
               abs(item[2]-bg_color[2]) < tolerance:
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)
        img.putdata(new_data)
        
        # Crop to bounding box
        bbox = img.getbbox()
        if bbox:
            img = img.crop(bbox)
        
        # Resize to fit within 128x128
        img.thumbnail((128, 128), Image.Resampling.LANCZOS)
        
        # Paste onto 128x128 canvas
        canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        offset = ((128 - img.width) // 2, (128 - img.height) // 2)
        canvas.paste(img, offset, img)
        canvas.save(out_path, "PNG")
        return True
    except Exception as e:
        print(f"Error processing {img_path}: {e}")
        return False

def generate_procedural_sprite(color_hex, out_path):
    img = Image.new("RGBA", (128, 128), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    
    # Draw a stylized creature silhouette (rounded rect/circle combo)
    # Body
    draw.rounded_rectangle([32, 48, 96, 112], radius=16, fill=color_hex, outline="black", width=2)
    # Head
    draw.ellipse([40, 24, 88, 72], fill=color_hex, outline="black", width=2)
    # Eyes
    draw.ellipse([50, 40, 58, 48], fill="white", outline="black", width=1)
    draw.ellipse([70, 40, 78, 48], fill="white", outline="black", width=1)
    draw.ellipse([53, 43, 56, 46], fill="black")
    draw.ellipse([73, 43, 76, 46], fill="black")
    
    img.save(out_path, "PNG")

# Locate artifact images
brain_dir = "C:/Users/pierr/.gemini/antigravity/brain/2a0fb6bc-718f-4333-ab82-a0a50c6751b8"
ratelit_img = glob.glob(brain_dir + "/ratelit_production*.jpg")
meerkit_img = glob.glob(brain_dir + "/meerkit_concept*.jpg")
pangolet_img = glob.glob(brain_dir + "/pangolet_concept*.jpg")

for cid, color in creatures.items():
    creature_dir = os.path.join(base_dir, cid)
    os.makedirs(creature_dir, exist_ok=True)
    out_file = os.path.join(creature_dir, "battle_idle.png")
    
    success = False
    if cid == "ratelit" and ratelit_img:
        success = remove_bg_and_crop(ratelit_img[0], out_file)
    elif cid == "meerkit" and meerkit_img:
        success = remove_bg_and_crop(meerkit_img[0], out_file)
    elif cid == "pangolet" and pangolet_img:
        success = remove_bg_and_crop(pangolet_img[0], out_file)
        
    if not success:
        generate_procedural_sprite(color, out_file)

print("Generated 30 creature sprites.")
