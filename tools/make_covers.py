"""Build Standard-Ebooks-style covers and inject them into EPUBs (dev tool, needs Pillow + macOS Arial).

usage: make_covers.py SRC_DIR ART_DIR OUT_DIR
For each entry in BOOKS: art image -> 1400x2100 cover with a dark title box,
written over the EPUB's existing cover image (same path and format), saved
to OUT_DIR under a readable filename.
"""
import io, re, sys, zipfile, posixpath
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

# (gutenberg id, output name, title, author, art file)
BOOKS = [
    (935,   "samuel-smiles_self-help",                 "Self-Help",                         "Samuel Smiles",       "smiles.jpg"),
    (17976, "andrew-carnegie_autobiography",           "The Autobiography of Andrew Carnegie", "Andrew Carnegie",   "carnegie.jpg"),
    (7213,  "henry-ford_my-life-and-work",             "My Life and Work",                  "Henry Ford",          "ford.jpg"),
    (2274,  "arnold-bennett_how-to-live-on-24-hours-a-day", "How to Live on 24 Hours a Day", "Arnold Bennett",     "clock.jpg"),
    (4507,  "james-allen_as-a-man-thinketh",           "As a Man Thinketh",                 "James Allen",         "thinker.jpg"),
    (4028,  "benvenuto-cellini_autobiography",         "The Autobiography of Benvenuto Cellini", "Benvenuto Cellini", "cellini.jpg"),
    (2010,  "charles-darwin_autobiography",            "The Autobiography of Charles Darwin", "Charles Darwin",    "darwin.jpg"),
    (674,   "plutarch_lives",                          "Lives of the Noble Grecians and Romans", "Plutarch",        "plutarch.jpg"),
    (5768,  "sam-williams_free-as-in-freedom",         "Free as in Freedom",                "Sam Williams",        "stallman.jpg"),
    (101,   "bruce-sterling_the-hacker-crackdown",     "The Hacker Crackdown",              "Bruce Sterling",      "sterling.jpg"),
]

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

def make_cover(art_path, title, author):
    art = ImageOps.exif_transpose(Image.open(art_path)).convert("RGB")
    img = ImageOps.fit(art, (W, H), Image.LANCZOS, centering=(0.5, 0.3))
    d = ImageDraw.Draw(img, "RGBA")
    tfont = ImageFont.truetype(BOLD, 92)
    afont = ImageFont.truetype(BOLD, 44)
    box_w = W - 160
    lines = wrap(d, title.upper(), tfont, box_w - 100)
    line_h = 106
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

def cover_path(z):
    container = z.read("META-INF/container.xml").decode("utf-8", "ignore")
    opf_path = re.search(r'full-path="([^"]+)"', container).group(1)
    opf = z.read(opf_path).decode("utf-8", "ignore")
    for it in re.findall(r"<item\b[^>]*>", opf):
        if "cover-image" in it:
            href = re.search(r'href="([^"]+)"', it).group(1)
            return posixpath.normpath(posixpath.join(posixpath.dirname(opf_path), href))
    raise ValueError("no cover-image item")

def main():
    src, art_dir, out = map(Path, sys.argv[1:4])
    out.mkdir(parents=True, exist_ok=True)
    for gid, name, title, author, art in BOOKS:
        epub = src / f"{gid}.epub"
        cover = make_cover(art_dir / art, title, author)
        with zipfile.ZipFile(epub) as zin:
            cpath = cover_path(zin)
            buf = io.BytesIO()
            fmt = "PNG" if cpath.lower().endswith(".png") else "JPEG"
            cover.save(buf, fmt, **({"quality": 90} if fmt == "JPEG" else {}))
            dest = out / f"{name}.epub"
            with zipfile.ZipFile(dest, "w") as zout:
                # mimetype must be first and stored uncompressed
                zout.writestr(zipfile.ZipInfo("mimetype"), zin.read("mimetype"), zipfile.ZIP_STORED)
                for info in zin.infolist():
                    if info.filename == "mimetype":
                        continue
                    data = buf.getvalue() if info.filename == cpath else zin.read(info.filename)
                    zout.writestr(info.filename, data, zipfile.ZIP_DEFLATED)
        cover.save(out / f"{name}.cover.jpg", "JPEG", quality=80)
        print(f"{dest.name}\t{cpath}")

main()
