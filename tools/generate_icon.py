"""
生成 bit_manager 主 icon (1024x1024 PNG)。

设计:
  - 紫 (#6366F1) -> 青 (#06B6D4) 对角渐变
  - 圆角 25% (iOS/Android 现代 icon 风格)
  - 主元素: 几何 "b" 字母, 白色
  - 装饰: 右上角 0/1 比特 (使用 monospace 字体)
"""
from PIL import Image, ImageDraw, ImageFont

# 颜色
PURPLE = (99, 102, 241)   # #6366F1
CYAN = (6, 182, 212)      # #06B6D4
WHITE = (255, 255, 255)
ALPHA = 30                # 装饰元素的透明度 (0-255)

SIZE = 1024
CORNER_RADIUS = int(SIZE * 0.225)  # iOS squircle 视觉 ~ 22.5%
SAFE = int(SIZE * 0.12)

# 字体
FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"
FONT_MONO = r"C:\Windows\Fonts\consola.ttf"

# 1. 创建画布, 透明背景 (用于圆角蒙版)
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 2. 画对角渐变背景
# 沿 (0,0) -> (SIZE, SIZE) 方向的线性渐变, 用 PIL 逐像素填充
gradient = Image.new("RGB", (SIZE, SIZE))
gpix = gradient.load()
top_left = PURPLE
bottom_right = CYAN
for y in range(SIZE):
    for x in range(SIZE):
        s = (x + y) / (2 * (SIZE - 1))
        r = int(top_left[0] * (1 - s) + bottom_right[0] * s)
        g = int(top_left[1] * (1 - s) + bottom_right[1] * s)
        b = int(top_left[2] * (1 - s) + bottom_right[2] * s)
        gpix[x, y] = (r, g, b)

# 3. 圆角蒙版
mask = Image.new("L", (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle(
    [(0, 0), (SIZE - 1, SIZE - 1)],
    radius=CORNER_RADIUS,
    fill=255,
)

# 4. 把渐变贴到透明画布
img.paste(gradient, (0, 0), mask)

# 5. 重新创建 draw 对象 (paste 后原 draw 仍然可用)
draw = ImageDraw.Draw(img)

# 6. 画主 "b" 字母 (大, 居中略偏下)
# 让字母主体在安全区内, 视觉上略大以占主导
b_size = int(SIZE * 0.62)  # 字体大小
font_b = ImageFont.truetype(FONT_BOLD, b_size)

# 测量字形 bounding box
bbox = draw.textbbox((0, 0), "b", font=font_b)
b_w = bbox[2] - bbox[0]
b_h = bbox[3] - bbox[1]

# 中心点 (略偏左下, 视觉平衡)
cx, cy = SIZE // 2 - 30, SIZE // 2 + 40
draw.text(
    (cx - b_w // 2 - bbox[0], cy - b_h // 2 - bbox[1]),
    "b",
    font=font_b,
    fill=WHITE,
)

# 7. 装饰: 右上角 0/1 比特
# 透明度处理: 用 RGBA 叠一层
overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)

mono_size = int(SIZE * 0.078)
font_m = ImageFont.truetype(FONT_MONO, mono_size)

bits = "01"
mb = od.textbbox((0, 0), bits, font=font_m)
mw = mb[2] - mb[0]
mh = mb[3] - mb[1]

# 位置: 右上安全区内
bits_x = SIZE - SAFE - mw
bits_y = SAFE
od.text(
    (bits_x - mb[0], bits_y - mb[1]),
    bits,
    font=font_m,
    fill=(255, 255, 255, ALPHA * 6),  # 稍微增强可见度
)

# 合并 overlay
img = Image.alpha_composite(img, overlay)

# 8. 下方小细节: 横线 "───" 表示列表/下载条目
# 略去, 保持简洁

# 9. 保存
out = r"D:\code\flutter\bit-manager\assets\icon\app_icon.png"
img.save(out, "PNG")
print(f"已生成: {out}")
print(f"尺寸: {img.size}, 模式: {img.mode}")
