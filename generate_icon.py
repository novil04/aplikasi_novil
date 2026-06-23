"""
Script untuk generate icon dan splash screen
Sesuai dengan desain loading screen aplikasi Pengering Ikan
"""

from PIL import Image, ImageDraw, ImageFont
import os

# Buat folder assets jika belum ada
os.makedirs("assets/images", exist_ok=True)

# ========================================
# 1. GENERATE APP ICON (1024x1024)
# ========================================

print("🎨 Generating app icon...")

# Buat canvas
icon_size = 1024
icon = Image.new('RGB', (icon_size, icon_size), color='white')
draw = ImageDraw.Draw(icon)

# Background gradient biru (simplified - solid blue)
# Untuk gradient yang lebih bagus, butuh library tambahan
# Kita pakai solid blue yang matching
blue_color = (25, 118, 210)  # #1976D2
draw.rectangle([0, 0, icon_size, icon_size], fill=blue_color)

# Gambar lingkaran putih di tengah
circle_radius = 350
circle_center = (icon_size // 2, icon_size // 2)
draw.ellipse(
    [
        circle_center[0] - circle_radius,
        circle_center[1] - circle_radius,
        circle_center[0] + circle_radius,
        circle_center[1] + circle_radius
    ],
    fill='white'
)

# Gambar icon ikan (simplified - gunakan emoji atau text)
# Karena kita tidak bisa render Material Icons, kita gunakan emoji ikan
try:
    # Coba load font yang support emoji
    font_size = 400
    # Windows default font
    font = ImageFont.truetype("seguiemj.ttf", font_size)
except:
    # Fallback ke default font
    font = ImageFont.load_default()

# Gambar emoji ikan di tengah
fish_emoji = "🐟"
# Get text bounding box
bbox = draw.textbbox((0, 0), fish_emoji, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
text_x = (icon_size - text_width) // 2
text_y = (icon_size - text_height) // 2 - 50

draw.text((text_x, text_y), fish_emoji, fill=blue_color, font=font)

# Save icon
icon.save("assets/images/app_icon.png")
print("✅ App icon saved: assets/images/app_icon.png")

# ========================================
# 2. GENERATE SPLASH SCREEN (1080x1920)
# ========================================

print("🖼️  Generating splash screen...")

# Buat canvas
splash_width = 1080
splash_height = 1920
splash = Image.new('RGB', (splash_width, splash_height), color='white')
draw = ImageDraw.Draw(splash)

# Background gradient biru (simplified - solid blue)
draw.rectangle([0, 0, splash_width, splash_height], fill=blue_color)

# Gambar lingkaran putih di tengah (lebih kecil untuk splash)
circle_radius_splash = 200
circle_center_splash = (splash_width // 2, splash_height // 2 - 200)
draw.ellipse(
    [
        circle_center_splash[0] - circle_radius_splash,
        circle_center_splash[1] - circle_radius_splash,
        circle_center_splash[0] + circle_radius_splash,
        circle_center_splash[1] + circle_radius_splash
    ],
    fill='white'
)

# Gambar icon ikan
try:
    font_splash = ImageFont.truetype("seguiemj.ttf", 220)
except:
    font_splash = ImageFont.load_default()

bbox = draw.textbbox((0, 0), fish_emoji, font=font_splash)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
text_x = (splash_width - text_width) // 2
text_y = circle_center_splash[1] - text_height // 2 - 30

draw.text((text_x, text_y), fish_emoji, fill=blue_color, font=font_splash)

# Tambah text "Pengering Ikan"
try:
    title_font = ImageFont.truetype("arialbd.ttf", 80)
except:
    title_font = ImageFont.load_default()

title_text = "Pengering Ikan"
bbox = draw.textbbox((0, 0), title_text, font=title_font)
title_width = bbox[2] - bbox[0]
title_x = (splash_width - title_width) // 2
title_y = circle_center_splash[1] + circle_radius_splash + 100

draw.text((title_x, title_y), title_text, fill='white', font=title_font)

# Tambah subtitle
try:
    subtitle_font = ImageFont.truetype("arial.ttf", 40)
except:
    subtitle_font = ImageFont.load_default()

subtitle_text = "Monitoring & Control System"
bbox = draw.textbbox((0, 0), subtitle_text, font=subtitle_font)
subtitle_width = bbox[2] - bbox[0]
subtitle_x = (splash_width - subtitle_width) // 2
subtitle_y = title_y + 100

# Warna putih dengan opacity (simplified - pakai putih biasa)
draw.text((subtitle_x, subtitle_y), subtitle_text, fill=(255, 255, 255, 180), font=subtitle_font)

# Save splash
splash.save("assets/images/splash.png")
print("✅ Splash screen saved: assets/images/splash.png")

print("")
print("========================================")
print("✅ DONE!")
print("========================================")
print("")
print("📊 Generated files:")
print("   - assets/images/app_icon.png (1024x1024)")
print("   - assets/images/splash.png (1080x1920)")
print("")
print("🚀 Next steps:")
print("   1. Run: .\\setup-icon-splash.ps1")
print("   2. Run: .\\build-apk.ps1")
print("")
