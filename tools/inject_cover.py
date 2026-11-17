"""Set the cover image of an EPUB. Standard library only.

usage: inject_cover.py BOOK.epub COVER.jpg

- If the EPUB declares a cover image, the new one replaces it. A format
  change (png -> jpg) updates the manifest item and any page that showed it.
- If it declares none, the cover is added: manifest item with
  properties="cover-image", <meta name="cover">, and a cover page first in
  the spine so readers that look for one find it.
The book is rewritten in place; on any error it is left untouched.
"""
import os, posixpath, re, sys, tempfile, zipfile

COVER_XHTML = """<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Cover</title>
<style>body{margin:0;text-align:center}img{max-width:100%;max-height:100%}</style></head>
<body><img src="{src}" alt="Cover"/></body></html>
"""


def main(book, cover):
    with open(cover, "rb") as f:
        new = f.read()
    ext = os.path.splitext(cover)[1].lower().replace(".jpeg", ".jpg")
    mime = {"jpg": "image/jpeg", "png": "image/png"}[ext[1:]]

    with zipfile.ZipFile(book) as zin:
        names = zin.namelist()
        container = zin.read("META-INF/container.xml").decode("utf-8", "ignore")
        opf_path = re.search(r'full-path="([^"]+)"', container).group(1)
        opf_dir = posixpath.dirname(opf_path)
        opf = zin.read(opf_path).decode("utf-8", "ignore")
        full = lambda href: posixpath.normpath(posixpath.join(opf_dir, href))

        item = None
        for it in re.findall(r"<item\b[^>]*/?>", opf):
            if "cover-image" in it:
                item = it; break
        if item is None:
            m = re.search(r'<meta\s[^>]*name="cover"[^>]*content="([^"]+)"', opf)
            if m:
                for it in re.findall(r"<item\b[^>]*/?>", opf):
                    if re.search(r'\bid="%s"' % re.escape(m.group(1)), it):
                        item = it; break

        replaced = {}            # zip name -> new bytes
        if item is not None:
            old_href = re.search(r'href="([^"]+)"', item).group(1)
            old_path = full(old_href)
            if posixpath.splitext(old_path)[1].lower().replace(".jpeg", ".jpg") == ext:
                new_path = old_path
            else:
                new_href = posixpath.splitext(old_href)[0] + ext
                new_path = full(new_href)
                new_item = item.replace(f'href="{old_href}"', f'href="{new_href}"')
                new_item = re.sub(r'media-type="[^"]+"', f'media-type="{mime}"', new_item)
                opf = opf.replace(item, new_item)
                base = posixpath.basename(old_href)
                for n in names:            # pages that show the old cover
                    if re.search(r"\.x?html?$", n, re.I):
                        page = zin.read(n).decode("utf-8", "ignore")
                        if base in page:
                            replaced[n] = page.replace(base, posixpath.basename(new_href)).encode("utf-8")
                replaced[old_path] = None  # drop the old image
            replaced[new_path] = new
            replaced[opf_path] = opf.encode("utf-8")
        else:
            img_href, page_href = "kit-cover" + ext, "kit-cover.xhtml"
            opf = opf.replace("</manifest>",
                f'<item id="kit-cover-image" href="{img_href}" media-type="{mime}" properties="cover-image"/>\n'
                f'<item id="kit-cover-page" href="{page_href}" media-type="application/xhtml+xml"/>\n</manifest>')
            opf = re.sub(r"(<spine\b[^>]*>)", r'\1\n<itemref idref="kit-cover-page"/>', opf, count=1)
            if '<meta name="cover"' not in opf:
                opf = opf.replace("</metadata>", '<meta name="cover" content="kit-cover-image"/>\n</metadata>')
            replaced[full(img_href)] = new
            replaced[full(page_href)] = COVER_XHTML.replace("{src}", img_href).encode("utf-8")
            replaced[opf_path] = opf.encode("utf-8")

        fd, tmp = tempfile.mkstemp(suffix=".epub", dir=os.path.dirname(os.path.abspath(book)))
        os.close(fd)
        with zipfile.ZipFile(tmp, "w") as zout:
            zout.writestr(zipfile.ZipInfo("mimetype"), zin.read("mimetype"), zipfile.ZIP_STORED)
            for info in zin.infolist():
                if info.filename == "mimetype":
                    continue
                if info.filename in replaced:
                    if replaced[info.filename] is None:
                        continue
                    zout.writestr(info.filename, replaced.pop(info.filename), zipfile.ZIP_DEFLATED)
                else:
                    zout.writestr(info.filename, zin.read(info.filename), zipfile.ZIP_DEFLATED)
            for name, data in replaced.items():   # newly added files
                if data is not None:
                    zout.writestr(name, data, zipfile.ZIP_DEFLATED)
    os.replace(tmp, book)


if __name__ == "__main__":
    main(*sys.argv[1:3])
