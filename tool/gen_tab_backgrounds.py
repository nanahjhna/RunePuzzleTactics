from PIL import Image
import os

def create_gradient(width, height, color1, color2, output_path):
    """Create a vertical gradient PNG."""
    img = Image.new('RGB', (width, height))
    for y in range(height):
        t = y / height
        r = int(color1[0] + (color2[0] - color1[0]) * t)
        g = int(color1[1] + (color2[1] - color1[1]) * t)
        b = int(color1[2] + (color2[2] - color1[2]) * t)
        for x in range(width):
            img.putpixel((x, y), (r, g, b))
    img.save(output_path, 'PNG')
    print(f"Created {output_path} ({width}x{height})")

output_dir = r'C:\Users\nanah\StudioProjects\RunePuzzleTactics\assets\background'
os.makedirs(output_dir, exist_ok=True)

# Tab backgrounds - dark, muted colors for game UI
tabs = {
    'lobby_bg.png': ((30, 25, 50), (60, 50, 100)),      # Dark purple
    'party_bg.png': ((20, 40, 30), (40, 80, 60)),       # Dark green
    'shop_bg.png': ((50, 40, 20), (100, 80, 40)),       # Dark gold/brown
    'settings_bg.png': ((30, 30, 35), (60, 60, 70)),    # Dark gray
}

for filename, (color1, color2) in tabs.items():
    create_gradient(1080, 1920, color1, color2, os.path.join(output_dir, filename))

print("\nAll dummy PNG files created successfully!")
