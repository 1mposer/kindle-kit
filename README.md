<div align="center">

```
   _    _           _ _             _    _ _
  | | _(_)_ __   __| | | ___       | | _(_) |_
  | |/ / | '_ \ / _` | |/ _ \ _____| |/ / | __|
  |   <| | | | | (_| | |  __/|_____|   <| | |_
  |_|\_\_|_| |_|\__,_|_|\___|      |_|\_\_|\__|

        .------------------------.
        |  .------------------.  |
        |  |                  |  |
        |  |   jailbreak  ->  |  |
        |  |   koreader   ->  |  |
        |  |   library    ->  |  |
        |  |   done.          |  |
        |  |                  |  |
        |  '------------------'  |
        |          ____          |
        '------------------------'
```

**Plug in your Kindle. Run one command. Get a better e-reader.**

![platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![firmware](https://img.shields.io/badge/firmware-5.16.3%20--%205.19.5-blue)
![license](https://img.shields.io/badge/license-MIT-green)

</div>

---

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/1mposer/kindle-kit/main/install.sh | bash
```

Run it, do the few steps it prints on the Kindle, plug back in, run it again.
It works out which stage your Kindle is at.

## What it does

| Stage | On your computer | On the Kindle |
|---|---|---|
| **1. Prep** | Copies the SpiderCat jailbreak book, fills storage to block updates | Open the book, wait for reboot, `;kpm install koreader` |
| **2. Setup** | Removes filler and pending updates, installs everything below | Open KOReader (or tap through the steps below) |

**Installed in stage 2**

- **Project: Title** - a cover-based library for KOReader, version-matched automatically
- **Webster's 1913** - 160,000-word unabridged dictionary, long-press any word
- **12 sleep screens** - Durer, Dore, Hiroshige, Haeckel and more, e-ink ready
- **41 free books** on six shelves, with proper covers
- **Reading setup** (optional) - Literata font, library as home screen, sleep screens on, chapter-only e-ink flashes
- **Book inbox** (optional) - type a title on your phone, the free EPUB lands on the Kindle ([kindle-inbox](https://github.com/1mposer/kindle-inbox))

```
documents/Library/
  Philosophy & Strategy     Meditations, Seneca, Nietzsche, The Prince, Walden ...
  Biographies & Achievers   Franklin, Carnegie, Ford, Grant, Douglass, Darwin ...
  Focus & Self-Mastery      Self-Help, How to Live on 24 Hours a Day ...
  Software & Coding         SICP, Pro Git, Eloquent JavaScript, Hacker Crackdown
  Classic Fiction           Dostoevsky, Tolstoy, Kafka, Homer, Melville ...
  Science & Economics       The Origin of Species, The Wealth of Nations
```

Every book is public domain or freely licensed and is downloaded from its
official source. Edit [`books.txt`](books.txt) to change the list.

## Requirements

- macOS or Linux with `python3` and `curl`
- A Kindle that mounts as a USB drive, on firmware **5.16.3 to 5.19.5**
  (check: Settings > Device options > Device info)
- Wi-Fi on the Kindle

Newer MTP-only models (Kindle 2024, Paperwhite 6, Scribe) are not supported.

## After setup

With the reading setup, KOReader opens on your Library and there is nothing
to tap. Without it:

```
Library view   wrench > More tools > Plugin management > Project: Title
Home folder    long-press documents/Library > Set as HOME folder
Sleep screen   gear > Screen > Sleep screen > Wallpaper > /mnt/us/screensavers
```

Do not update the Kindle past 5.19.5. The jailbreak keeps updates blocked.

## Credits

Built on [SpiderCat](https://github.com/KindleModding/SpiderCat) and the
[KindleModding guide](https://kindlemodding.org),
[KOReader](https://github.com/koreader/koreader),
[Project: Title](https://github.com/joshuacant/ProjectTitle),
[Kindle-Filler-Disk](https://github.com/iiroak/Kindle-Filler-Disk),
[Standard Ebooks](https://standardebooks.org) and
[Project Gutenberg](https://www.gutenberg.org).
Image and book sources are in [CREDITS.md](CREDITS.md).

Jailbreaking is at your own risk.
