"""Build Standard-Ebooks-style cover images (dev tool, needs Pillow + macOS Arial).

usage: make_covers.py MANIFEST.tsv ART_DIR OUT_DIR

MANIFEST lines:  stem <TAB> title <TAB> author <TAB> art file <TAB> focus
  focus  = vertical focus of the crop, 0.0 (top) .. 1.0 (bottom), or "raw"
           to use the art as the whole cover with no title box (an original
           cover scan, for example).
Writes OUT_DIR/<stem>.jpg at 1400x2100. install.sh injects assets/covers/<stem>.jpg
into the EPUB whose filename is <stem>.epub.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

W, H = 1400, 2100
BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"


def wrap(draw, text, font, maxw):
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=font) <= maxw:
            cur = trial
        else:
            lines.append(cur); cur = word
    lines.append(cur)
    return lines


def make_cover(art_path, title, author, focus):
    art = ImageOps.exif_transpose(Image.open(art_path)).convert("RGB")
    if focus == "raw":
        return ImageOps.fit(art, (W, H), Image.LANCZOS, centering=(0.5, 0.5))
    img = ImageOps.fit(art, (W, H), Image.LANCZOS, centering=(0.5, float(focus)))
    d = ImageDraw.Draw(img, "RGBA")
    size = 92
    tfont = ImageFont.truetype(BOLD, size)
    afont = ImageFont.truetype(BOLD, 44)
    box_w = W - 160
    lines = wrap(d, title.upper(), tfont, box_w - 100)
    while len(lines) > 4 and size > 60:          # long titles: shrink to fit
        size -= 8
        tfont = ImageFont.truetype(BOLD, size)
        lines = wrap(d, title.upper(), tfont, box_w - 100)
    line_h = int(size * 1.15)
    box_h = len(lines) * line_h + 150
    x0, y1 = 80, H - 110
    y0 = y1 - box_h
    d.rectangle([x0, y0, x0 + box_w, y1], fill=(0, 0, 0, 205))
    y = y0 + 50
    for ln in lines:
        d.text((W / 2, y), ln, font=tfont, fill="white", anchor="mt")
        y += line_h
    d.text((W / 2, y + 12), author.upper(), font=afont, fill=(230, 230, 230), anchor="mt")
    return img


def main():
    manifest, art_dir, out = map(Path, sys.argv[1:4])
    out.mkdir(parents=True, exist_ok=True)
    for line in manifest.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        stem, title, author, art, focus = line.split("\t")
        cover = make_cover(art_dir / art, title, author, focus)
        cover.save(out / f"{stem}.jpg", "JPEG", quality=82, optimize=True)
        print(stem)


main()
