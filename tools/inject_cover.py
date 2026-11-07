"""Replace the cover image inside an EPUB. Standard library only.

usage: inject_cover.py BOOK.epub COVER.(png|jpg)

The new cover is written over the image the EPUB already declares as its
cover, so it must be the same format. Exits non-zero (book left untouched)
if no cover is declared or the formats differ.
"""
import os, posixpath, re, sys, tempfile, zipfile


def cover_path(z):
    container = z.read("META-INF/container.xml").decode("utf-8", "ignore")
    opf_path = re.search(r'full-path="([^"]+)"', container).group(1)
    opf = z.read(opf_path).decode("utf-8", "ignore")
    for item in re.findall(r"<item\b[^>]*>", opf):
        if "cover-image" in item:
            href = re.search(r'href="([^"]+)"', item).group(1)
            return posixpath.normpath(posixpath.join(posixpath.dirname(opf_path), href))
    return None


def main(book, cover):
    with zipfile.ZipFile(book) as zin:
        target = cover_path(zin)
        if not target:
            sys.exit("no cover declared")
        norm = lambda p: os.path.splitext(p)[1].lower().replace(".jpeg", ".jpg")
        if norm(target) != norm(cover):
            sys.exit(f"format mismatch: {target}")
        with open(cover, "rb") as f:
            new = f.read()
        fd, tmp = tempfile.mkstemp(suffix=".epub", dir=os.path.dirname(os.path.abspath(book)))
        os.close(fd)
        with zipfile.ZipFile(tmp, "w") as zout:
            # EPUB rule: mimetype first, stored uncompressed
            zout.writestr(zipfile.ZipInfo("mimetype"), zin.read("mimetype"), zipfile.ZIP_STORED)
            for info in zin.infolist():
                if info.filename == "mimetype":
                    continue
                data = new if info.filename == target else zin.read(info.filename)
                zout.writestr(info.filename, data, zipfile.ZIP_DEFLATED)
    os.replace(tmp, book)


if __name__ == "__main__":
    main(*sys.argv[1:3])
