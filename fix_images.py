import os
from PIL import Image
import sys

files = [
    "/Users/tayap/apps-go/numberniceic/mobile_app/android/app/src/main/res/drawable/ic_lotus_yellow.png",
    "/Users/tayap/apps-go/numberniceic/mobile_app/android/app/src/main/res/drawable/ic_yellow_circle.png",
    "/Users/tayap/apps-go/numberniceic/mobile_app/android/app/src/main/res/mipmap-hdpi/ic_notification.png"
]

for f in files:
    try:
        # Open as whatever format it actually is (JPEG)
        img = Image.open(f)
        print(f"Opened {f}: format={img.format}")
        
        # Start looking for transparency issues or just convert
        # Since these were JPEGs, they have no alpha channel.
        # We just want to save them as valid PNGs.
        img.save(f, "PNG")
        print(f"Converted {f} to valid PNG.")
    except Exception as e:
        print(f"Failed to convert {f}: {e}")
