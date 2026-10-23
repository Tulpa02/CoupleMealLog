# -*- coding: utf-8 -*-
"""把设计稿生成 Android 各尺寸启动图标。

源图已是裁好的方形设计稿（深蓝圆角卡片铺满画面，四角为深蓝底色），
因此这里只做等比缩放，不再裁剪，避免切掉画面内容。
"""
import os
from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "assets", "icon_source.jpg")
ROOT = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                    "android", "app", "src", "main", "res")

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def main():
    img = Image.open(SRC).convert("RGB")
    w, h = img.size
    print("源图尺寸:", (w, h))

    # 裁成正方形（居中），保证缩放不变形
    if w != h:
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        img = img.crop((left, top, left + side, top + side))
        print("裁成正方形:", img.size)

    for folder, size in SIZES.items():
        out_dir = os.path.join(ROOT, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = img.resize((size, size), Image.LANCZOS)
        out_path = os.path.join(out_dir, "ic_launcher.png")
        resized.save(out_path, "PNG", optimize=True)
        print(f"{folder}/ic_launcher.png  {size}x{size}  "
              f"{os.path.getsize(out_path)} bytes")

    preview = os.path.join(os.path.dirname(__file__), "icon_preview.png")
    img.resize((512, 512), Image.LANCZOS).save(preview, "PNG")
    print("预览图:", preview)


if __name__ == "__main__":
    main()
