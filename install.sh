#!/usr/bin/env bash
# kindle-kit: jailbreak prep + KOReader setup for a USB-connected Kindle.
# Run it, follow the on-Kindle steps it prints, plug back in, run it again.
#
#   curl -fsSL https://raw.githubusercontent.com/1mposer/kindle-kit/main/install.sh | bash

set -euo pipefail

REPO="1mposer/kindle-kit"
LEAVE_FREE_MB=20
UA="kindle-kit/1.0 (+https://github.com/$REPO)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
ok()   { printf '  [ok] %s\n' "$*"; }
warn() { printf '  [!]  %s\n' "$*"; }
die()  { printf '\n  [x]  %s\n\n' "$*"; exit 1; }
ask()  { local a; read -r -p "  $1 [y/N] " a </dev/tty; [[ "$a" =~ ^[yY] ]]; }
ask_yes() { local a; read -r -p "  $1 [Y/n] " a </dev/tty; [[ ! "$a" =~ ^[nN] ]]; }
step() { printf '\n'; bold "== $* =="; }

fetch() { curl -fsSL -A "$UA" --retry 2 -o "$2" "$1"; }

cat <<'EOF'

   _    _           _ _             _    _ _
  | | _(_)_ __   __| | | ___       | | _(_) |_
  | |/ / | '_ \ / _` | |/ _ \ _____| |/ / | __|
  |   <| | | | | (_| | |  __/|_____|   <| | |_
  |_|\_\_|_| |_|\__,_|_|\___|      |_|\_\_|\__|

EOF

command -v python3 >/dev/null || die "python3 is required (macOS: xcode-select --install)."

# ---------------------------------------------------------------- assets
# Running from a clone uses local files; curl | bash pulls the repo tarball.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ ! -f "$SRC/books.txt" ]; then
    info "Downloading kindle-kit..."
    fetch "https://github.com/$REPO/archive/refs/heads/main.tar.gz" "$WORK/kit.tgz"
    tar xzf "$WORK/kit.tgz" -C "$WORK"
    SRC="$WORK/kindle-kit-main"
fi

# ---------------------------------------------------------------- detect
step "Finding your Kindle"
K=""
if [ "$(uname)" = "Darwin" ]; then
    for v in /Volumes/*; do
        case "$(basename "$v" | tr '[:upper:]' '[:lower:]')" in *kindle*) K="$v"; break ;; esac
    done
else
    K="$(findmnt -rn -o TARGET -S LABEL=Kindle 2>/dev/null | head -1 || true)"
fi
[ -n "$K" ] && [ -d "$K/documents" ] || die "No Kindle found. Plug it in over USB and unlock it.
       Newer models (2024 Basic, Paperwhite 6, Scribe) use MTP and are not supported."

FW="$(sed -n 's/^Kindle \([0-9.]*\).*/\1/p' "$K/system/version.txt" 2>/dev/null || true)"
ok "Kindle at $K"
ok "Firmware ${FW:-unknown}"

ver() { echo "$1" | awk -F. '{ printf "%d%03d%03d%03d", $1, $2, $3, $4 }'; }
free_mb() { df -Pm "$K" | awk 'NR==2 { print $4 }'; }

clean_mac_junk() {
    [ "$(uname)" = "Darwin" ] || return 0
    mdutil -i off "$K" >/dev/null 2>&1 || true
    rm -rf "$K/.Spotlight-V100"
    mkdir -p "$K/.fseventsd" && touch "$K/.fseventsd/no_log" "$K/.metadata_never_index"
    dot_clean -m "$K" 2>/dev/null || true
}

# ================================================================ stage 1
if [ ! -f "$K/documents/JAILBROKEN.txt" ] && [ ! -d "$K/libkh" ]; then
    step "Stage 1 of 2: jailbreak prep (SpiderCat)"
    [ -n "$FW" ] || die "Could not read the firmware version."
    if [ "$(ver "$FW")" -lt "$(ver 5.16.3)" ] || [ "$(ver "$FW")" -gt "$(ver 5.19.5)" ]; then
        die "SpiderCat supports firmware 5.16.3 to 5.19.5. Yours is $FW.
       See https://kindlemodding.org for other options."
    fi
    info "This copies the SpiderCat jailbreak book to the Kindle, then fills"
    info "its storage (leaving ${LEAVE_FREE_MB} MB) so it cannot download an update."
    ask "Continue?" || exit 0

    fetch "https://kindlemodding.org/spidercat/spidercat.azw3" "$K/documents/spidercat.azw3"
    ok "SpiderCat book copied"

    mkdir -p "$K/fill_disk"
    n=$(ls "$K/fill_disk" | wc -l | tr -d ' ')
    while :; do
        left=$(( $(free_mb) - LEAVE_FREE_MB ))
        [ "$left" -le 0 ] && break
        size=100; [ "$left" -lt 100 ] && size=$left
        truncate -s "${size}M" "$K/fill_disk/file_$n" 2>/dev/null ||
            dd if=/dev/zero of="$K/fill_disk/file_$n" bs=1m count="$size" 2>/dev/null ||
            dd if=/dev/zero of="$K/fill_disk/file_$n" bs=1M count="$size" 2>/dev/null
        n=$((n + 1))
        printf '\r  filling... %s MB free   ' "$(free_mb)"
    done
    printf '\n'; ok "Storage filled ($(free_mb) MB free)"
    clean_mac_junk

    step "Now on the Kindle"
    cat <<EOF
  1. Eject and unplug the Kindle. Keep Wi-Fi ON.
  2. Open "spidercat" from your Library. Ignore any error popups.
  3. Wait. Text scrolls, then it says "Restarting Kindle" and reboots.
  4. After the reboot, type in the search bar:   ;kpm update
     then:                                        ;kpm install koreader
  5. Plug the Kindle back in and run this script again.

  Stuck? https://kindlemodding.org/jailbreaking/SpiderCat/
EOF
    exit 0
fi

# ================================================================ stage 2
step "Stage 2 of 2: cleanup + KOReader setup"
ok "Kindle is jailbroken"

for f in "$K"/update*.bin "$K"/update.bin.tmp.partial; do
    { [ -e "$f" ] && rm -f "$f" && ok "Removed pending update $(basename "$f")"; } || true
done
[ -d "$K/fill_disk" ] && rm -rf "$K/fill_disk" && ok "Removed filler files"
rm -rf "$K/documents/spidercat.azw3" "$K/documents/spidercat.sdr"

if [ ! -d "$K/koreader" ]; then
    cat <<'EOF'

  KOReader is not installed yet. On the Kindle (Wi-Fi on), type in the search bar:
      ;kpm update
      ;kpm install koreader
  Then plug back in and run this script again.

EOF
    exit 0
fi
KO_VER="$(sed 's/^v//' "$K/koreader/git-rev" 2>/dev/null || true)"
ok "KOReader ${KO_VER:-found}"

# --- Project: Title (needs a release matching the KOReader version)
step "Project: Title (cover-based library)"
if [ -d "$K/koreader/plugins/projecttitle.koplugin" ]; then
    ok "Already installed"
else
    fetch "https://api.github.com/repos/joshuacant/ProjectTitle/releases?per_page=20" "$WORK/pt.json"
    PT_URL="$(python3 -I - "$WORK/pt.json" "$KO_VER" <<'PY'
import json, re, sys
releases, ko = json.load(open(sys.argv[1])), sys.argv[2]
mm = ".".join(ko.split(".")[:2])  # 2026.07.1 -> 2026.07
for r in releases:
    if r.get("prerelease"):
        continue
    if re.search(r"\b" + re.escape(mm) + r"\b", r.get("body") or ""):
        for a in r["assets"]:
            if a["name"].endswith(".zip"):
                print(a["browser_download_url"]); sys.exit()
PY
)"
    if [ -n "$PT_URL" ]; then
        fetch "$PT_URL" "$WORK/pt.zip"
        python3 -I -m zipfile -e "$WORK/pt.zip" "$WORK/pt"
        cp -R "$WORK/pt/projecttitle.koplugin" "$K/koreader/plugins/"
        ok "Installed $(basename "$PT_URL")"
    else
        warn "No Project: Title release matches KOReader $KO_VER yet. Skipped."
    fi
fi

# --- dictionary
step "Webster's 1913 dictionary"
DICT="$K/koreader/data/dict/stardict-dictd-web1913-2.4.2"
if [ -d "$DICT" ]; then
    ok "Already installed"
else
    fetch "https://raw.githubusercontent.com/ahacop/websters-dict-1913-stardict/main/stardict-dictd-web1913-2.4.2.tgz" "$WORK/dict.tgz"
    mkdir -p "$K/koreader/data/dict"
    tar xzf "$WORK/dict.tgz" -C "$K/koreader/data/dict"
    ok "Installed (160,161 words)"
fi

# --- screensavers
step "Sleep screens"
mkdir -p "$K/screensavers"
cp "$SRC"/assets/screensavers/*.png "$K/screensavers/"
ok "$(ls "$SRC"/assets/screensavers/*.png | wc -l | tr -d ' ') images in /screensavers (sized for Paperwhite 5, 1236x1648)"

# --- books
step "Free library"
added=0; skipped=0; failed=0
while IFS='|' read -r shelf src id name; do
    case "$shelf" in ''|\#*) continue ;; esac
    if [ "$src" = "se" ]; then
        name="$(echo "$id" | tr '/' '_').epub"
        url="https://standardebooks.org/ebooks/$id/downloads/$name?source=download"
    elif [ "$src" = "pg" ]; then
        url="https://www.gutenberg.org/ebooks/$id.epub3.images"
    else
        url="$id"
    fi
    dest="$K/documents/Library/$shelf/$name"
    if [ -s "$dest" ]; then skipped=$((skipped + 1)); continue; fi
    mkdir -p "$K/documents/Library/$shelf"
    if fetch "$url" "$WORK/book.epub" && [ "$(head -c 2 "$WORK/book.epub")" = "PK" ]; then
        if [ "$src" = "pg" ]; then
            for c in "$SRC/assets/covers/$id".*; do
                [ -f "$c" ] && python3 -I "$SRC/tools/inject_cover.py" "$WORK/book.epub" "$c" 2>/dev/null || true
            done
        fi
        cp "$WORK/book.epub" "$dest"
        added=$((added + 1)); printf '\r  %d books added   ' "$added"
    else
        failed=$((failed + 1)); printf '\n'; warn "Could not download $name"
    fi
    [ "$src" = "pg" ] && sleep 1   # be polite to Gutenberg
done < "$SRC/books.txt"
printf '\n'; ok "$added added, $skipped already there, $failed failed"

# --- reading setup (optional): Literata, Project: Title as home, quiet status bar
step "Reading setup"
SETUP=0
info "Literata font, library as home screen, Project: Title on, sleep screens on,"
info "chapter-only e-ink flashes, quieter status bar. Applied once on next start."
if ask_yes "Apply the recommended setup?"; then
    LIT="$K/koreader/fonts/literata"
    mkdir -p "$LIT"
    for f in Regular Italic Medium MediumItalic Bold BoldItalic; do
        [ -s "$LIT/Literata-$f.ttf" ] ||
            fetch "https://raw.githubusercontent.com/googlefonts/literata/main/fonts/ttf/Literata-$f.ttf" "$LIT/Literata-$f.ttf"
    done
    fetch "https://raw.githubusercontent.com/googlefonts/literata/main/OFL.txt" "$LIT/OFL.txt"
    ok "Literata installed (SIL Open Font License)"
    PT="$K/koreader/plugins/projecttitle.koplugin"
    mkdir -p "$K/koreader/patches"
    if [ -d "$PT/fonts/source" ] && [ -f "$PT/resources/2-font-override.lua" ]; then
        mkdir -p "$K/koreader/fonts/source"
        cp "$PT"/fonts/source/*.ttf "$K/koreader/fonts/source/"
        cp "$PT/resources/2-font-override.lua" "$K/koreader/patches/"
        ok "Project: Title menu font"
    fi
    cp "$SRC/assets/koreader/patches/2-kindle-kit-setup.lua" "$K/koreader/patches/"
    ok "Setup queued for the next KOReader start"
    SETUP=1
fi

# --- book inbox (optional): books sent from your phone
step "Book inbox (optional)"
info "Send a book title from your phone and it downloads to Library/Inbox."
info "Needs your own copy of github.com/1mposer/kindle-inbox (Use this template)."
if ask "Set it up now?"; then
    read -r -p "  Feed URL (https://<you>.github.io/<repo>/manifest.json): " FEED </dev/tty
    if [[ "$FEED" =~ ^https://[^[:space:]]+/manifest\.json$ ]]; then
        fetch "https://github.com/1mposer/kindle-inbox/archive/refs/heads/main.tar.gz" "$WORK/inbox.tgz"
        tar xzf "$WORK/inbox.tgz" -C "$WORK"
        rm -rf "$K/koreader/plugins/inboxsync.koplugin"
        cp -R "$WORK/kindle-inbox-main/inboxsync.koplugin" "$K/koreader/plugins/"
        printf '%s\n' "$FEED" > "$K/koreader/plugins/inboxsync.koplugin/feed_url.txt"
        mkdir -p "$K/documents/Library/Inbox"
        ok "Inbox plugin installed"
    else
        warn "That does not look like a manifest.json URL. Skipped."
    fi
fi

clean_mac_junk

step "Done. Finish on the Kindle"
if [ "$SETUP" = 1 ]; then
cat <<'EOF'
  1. Eject and unplug. Open KOReader. It opens on your Library.
  2. Open a book. Font, spacing and the status bar are already set.
  3. Dictionary:    long-press any word. Set order in Dictionary settings.
  4. Warm light:    swipe up/down on the right edge. Brightness: left edge.

  Updates stay blocked by the jailbreak. Do not update past firmware 5.19.5.
EOF
else
cat <<'EOF'
  1. Eject and unplug. Open KOReader.
  2. Library view:  wrench > More tools > Plugin management
                    uncheck "Cover browser", check "Project: Title", Restart.
  3. Home folder:   long-press documents/Library > Set as HOME folder.
  4. Sleep screen:  gear > Screen > Sleep screen > Wallpaper
                    > Show random image from folder > /mnt/us/screensavers
  5. Dictionary:    long-press any word. Set order in Dictionary settings.

  Updates stay blocked by the jailbreak. Do not update past firmware 5.19.5.
EOF
fi
