import os
from PIL import Image

def generate_icons():
    logo_path = 'assets/images/app_logo.png'
    if not os.path.exists(logo_path):
        print(f"Error: {logo_path} not found!")
        return

    full_logo = Image.open(logo_path).convert('RGBA')
    width, height = full_logo.size
    pixels = full_logo.load()

    # Create monochrome silhouette with cutout for Android status bar
    silhouette = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    sil_pixels = silhouette.load()

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if r < 35 and g < 35 and b < 40:
                sil_pixels[x, y] = (0, 0, 0, 0)
            else:
                if r > 240 and g > 240 and b > 240:
                    sil_pixels[x, y] = (0, 0, 0, 0)
                else:
                    sil_pixels[x, y] = (255, 255, 255, 255)

    # Densities for Android
    densities = {
        'mdpi': {'launcher': 48, 'stat': 24},
        'hdpi': {'launcher': 72, 'stat': 36},
        'xhdpi': {'launcher': 96, 'stat': 48},
        'xxhdpi': {'launcher': 144, 'stat': 72},
        'xxxhdpi': {'launcher': 192, 'stat': 96},
    }

    base_res = 'android/app/src/main/res'

    for density, sizes in densities.items():
        # Drawables
        drawable_dir = os.path.join(base_res, f'drawable-{density}')
        os.makedirs(drawable_dir, exist_ok=True)

        launcher_img = full_logo.resize((sizes['launcher'], sizes['launcher']), Image.Resampling.LANCZOS)
        stat_img = silhouette.resize((sizes['stat'], sizes['stat']), Image.Resampling.LANCZOS)

        launcher_img.save(os.path.join(drawable_dir, 'ic_launcher.png'))
        launcher_img.save(os.path.join(drawable_dir, 'launcher_icon.png'))
        launcher_img.save(os.path.join(drawable_dir, 'ic_notification.png'))
        stat_img.save(os.path.join(drawable_dir, 'ic_stat_onesignal_default.png'))

        # Mipmaps
        mipmap_dir = os.path.join(base_res, f'mipmap-{density}')
        os.makedirs(mipmap_dir, exist_ok=True)
        launcher_img.save(os.path.join(mipmap_dir, 'ic_launcher.png'))
        launcher_img.save(os.path.join(mipmap_dir, 'launcher_icon.png'))
        launcher_img.save(os.path.join(mipmap_dir, 'ic_notification.png'))

    # Root drawable folder
    root_drawable = os.path.join(base_res, 'drawable')
    os.makedirs(root_drawable, exist_ok=True)
    full_logo.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(root_drawable, 'ic_launcher.png'))
    full_logo.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(root_drawable, 'launcher_icon.png'))
    full_logo.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(root_drawable, 'ic_notification.png'))
    silhouette.resize((96, 96), Image.Resampling.LANCZOS).save(os.path.join(root_drawable, 'ic_stat_onesignal_default.png'))

    print("Android icons successfully created!")

    # iOS AppIcon.appiconset
    ios_icons = {
        'Icon-App-20x20@1x.png': 20,
        'Icon-App-20x20@2x.png': 40,
        'Icon-App-20x20@3x.png': 60,
        'Icon-App-29x29@1x.png': 29,
        'Icon-App-29x29@2x.png': 58,
        'Icon-App-29x29@3x.png': 87,
        'Icon-App-40x40@1x.png': 40,
        'Icon-App-40x40@2x.png': 80,
        'Icon-App-40x40@3x.png': 120,
        'Icon-App-50x50@1x.png': 50,
        'Icon-App-50x50@2x.png': 100,
        'Icon-App-57x57@1x.png': 57,
        'Icon-App-57x57@2x.png': 114,
        'Icon-App-60x60@2x.png': 120,
        'Icon-App-60x60@3x.png': 180,
        'Icon-App-72x72@1x.png': 72,
        'Icon-App-72x72@2x.png': 144,
        'Icon-App-76x76@1x.png': 76,
        'Icon-App-76x76@2x.png': 152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
    }

    ios_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    if os.path.exists(ios_dir):
        # iOS AppIcon requires RGB (no alpha) for App Store 1024x1024
        rgb_logo = full_logo.convert('RGB')
        for filename, size in ios_icons.items():
            img_to_save = rgb_logo.resize((size, size), Image.Resampling.LANCZOS)
            img_to_save.save(os.path.join(ios_dir, filename))
        print("iOS AppIcons successfully generated!")

if __name__ == '__main__':
    generate_icons()
