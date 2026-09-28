#!/usr/bin/env python3
"""Erzeugt alle Pixel-Art-Sprites und Icons für Abduct-O-Matic.

Aufruf:  python3 tools/make_sprites.py   (aus dem Projektordner)
Die PNGs landen in assets/sprites und assets/icons. Jede Figur ist ein
Spritesheet mit 4 Frames nebeneinander: 0/1 = Laufen, 2 = Reaktion, 3 = Eingesaugt.
Einfach durch eigene Grafiken ersetzen – gleiche Framegröße beibehalten.
"""
from PIL import Image
import os, math, random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
ICO = os.path.join(ROOT, "assets", "icons")
os.makedirs(SPR, exist_ok=True)
os.makedirs(ICO, exist_ok=True)

OUT = (24, 20, 34, 255)


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


class Sheet:
    def __init__(self, fw, fh, frames=4):
        self.fw, self.fh, self.frames = fw, fh, frames
        self.img = Image.new("RGBA", (fw * frames, fh), (0, 0, 0, 0))
        self.f = 0

    def frame(self, i):
        self.f = i
        return self

    def px(self, x, y, c):
        if 0 <= x < self.fw and 0 <= y < self.fh and c is not None:
            self.img.putpixel((self.f * self.fw + x, y), c)

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.px(xx, yy, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for xx in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((xx + 0.5 - cx) / rx) ** 2 + ((yy + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.px(xx, yy, c)

    def outline(self, color=OUT):
        """Fügt um alle nicht-transparenten Pixel einen 1px-Rand hinzu (pro Frame)."""
        src = self.img.copy()
        W, H = self.img.size
        for fi in range(self.frames):
            x0 = fi * self.fw
            for y in range(self.fh):
                for x in range(x0, x0 + self.fw):
                    if src.getpixel((x, y))[3] != 0:
                        continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if x0 <= nx < x0 + self.fw and 0 <= ny < H and src.getpixel((nx, ny))[3] > 0 and src.getpixel((nx, ny)) != color:
                            self.img.putpixel((x, y), color)
                            break
        return self

    def save(self, name, folder=SPR):
        self.img.save(os.path.join(folder, name + ".png"))


# ---------------------------------------------------------------- Menschen

def human(name, skin, hair, shirt, pants, hat=None, style="normal", extra=None):
    s = Sheet(14, 20)
    for f in range(4):
        s.frame(f)
        arms_up = f in (2, 3)
        stride = f == 1 or f == 2
        # Beine
        shoe = hexc("2a2230")
        if style == "robe":
            s.rect(4, 8, 6, 9, shirt)
            s.rect(4, 17, 2, 1, shoe) if not stride else s.rect(3, 17, 2, 1, shoe)
            s.rect(8, 17, 2, 1, shoe) if not stride else s.rect(9, 17, 2, 1, shoe)
        else:
            if f == 3:
                s.rect(3, 14, 2, 4, pants); s.rect(9, 14, 2, 4, pants)
            elif stride:
                s.rect(4, 14, 2, 3, pants); s.rect(3, 16, 2, 2, pants)
                s.rect(8, 14, 2, 3, pants); s.rect(9, 16, 2, 2, pants)
                s.rect(2, 17, 2, 1, shoe); s.rect(10, 17, 2, 1, shoe)
            else:
                s.rect(5, 14, 2, 4, pants); s.rect(7, 14, 2, 4, pants)
                s.rect(5, 17, 2, 1, shoe); s.rect(7, 17, 2, 1, shoe)
        # Körper
        s.rect(4, 8, 6, 6, shirt)
        if style == "suit":
            s.rect(6, 8, 2, 4, hexc("ffffff")); s.px(6, 9, hexc("d02040")); s.px(7, 9, hexc("d02040"))
        if style == "coat":
            s.rect(4, 8, 6, 8, shirt); s.px(6, 10, hexc("6b4a2a")); s.px(6, 12, hexc("6b4a2a"))
        if style == "parka":
            s.rect(3, 7, 8, 8, shirt)
        # Arme
        sleeve = tuple(max(0, v - 25) if i < 3 else v for i, v in enumerate(shirt))
        if arms_up:
            s.rect(2, 3, 2, 6, sleeve); s.rect(10, 3, 2, 6, sleeve)
            s.rect(2, 2, 2, 1, skin); s.rect(10, 2, 2, 1, skin)
        else:
            s.rect(2, 8, 2, 5, sleeve); s.rect(10, 8, 2, 5, sleeve)
            s.rect(2, 13, 2, 1, skin); s.rect(10, 13, 2, 1, skin)
        # Kopf
        s.rect(4, 2, 6, 6, skin)
        s.rect(4, 2, 6, 2, hair)
        s.px(4, 4, hair)
        if style == "parka":
            s.rect(3, 1, 8, 2, shirt); s.rect(3, 1, 1, 7, shirt); s.rect(10, 1, 1, 7, shirt)
        if hat:
            s.rect(3, 1, 8, 1, hat); s.rect(4, 0, 6, 1, hat)
        # Gesicht
        eye = hexc("1a1420")
        if f == 3:
            s.px(6, 4, hexc("ffffff")); s.px(8, 4, hexc("ffffff")); s.px(6, 5, eye); s.px(8, 5, eye)
            s.rect(7, 6, 1, 1, eye)
        elif f == 2:
            s.px(6, 4, eye); s.px(8, 4, eye); s.rect(7, 6, 1, 1, eye)
        else:
            s.px(6, 4, eye); s.px(8, 4, eye)
        if style == "suit":  # Sonnenbrille
            s.rect(5, 4, 5, 1, hexc("101010"))
        if extra == "antenna":
            s.px(7, 0, hexc("5cff6a")); s.px(7, 1, hexc("2f9e3a"))
        if extra == "helmet":
            s.rect(3, 1, 8, 2, hexc("ffcc22")); s.px(6, 0, hexc("ffcc22")); s.px(7, 0, hexc("ffcc22"))
    s.outline().save(name)


SKINS = ["ffd9b8", "f0bc92", "c68a5c", "8d5a3a", "5e3b25"]
HAIRS = ["2a1d14", "6b3f1c", "f2d06b", "b8481c", "cccccc"]
SHIRTS = ["e8454f", "3f86f2", "ffcf3a", "47c96b", "b064e8", "ff8c32", "f5f5f5"]
PANTS = ["2f3a6b", "444450", "6b5236", "22222c"]
random.seed(7)
for i in range(6):
    human("human_%d" % i, hexc(SKINS[i % 5]), hexc(HAIRS[(i * 2) % 5]), hexc(SHIRTS[i % 7]), hexc(PANTS[i % 4]),
          hat=hexc("303040") if i == 4 else None)
human("celebrity", hexc("ffd9b8"), hexc("ffe27a"), hexc("ffd23a"), hexc("ffd23a"), style="suit")
human("spy", hexc("cfe8b0"), hexc("2a1d14"), hexc("c9b48a"), hexc("3a3a40"), hat=hexc("5a4630"), style="coat", extra="antenna")
human("nomad_0", hexc("c68a5c"), hexc("f5f0e0"), hexc("f5f0e0"), hexc("d8c8a0"), style="robe")
human("nomad_1", hexc("8d5a3a"), hexc("3f86f2"), hexc("3f86f2"), hexc("3060b0"), style="robe")
human("parka_0", hexc("ffd9b8"), hexc("6b3f1c"), hexc("e8454f"), hexc("2f3a6b"), style="parka")
human("parka_1", hexc("c68a5c"), hexc("2a1d14"), hexc("47c96b"), hexc("22222c"), style="parka")
human("engineer_0", hexc("f0bc92"), hexc("2a1d14"), hexc("ff8c32"), hexc("2f3a6b"), extra="helmet")
human("engineer_1", hexc("8d5a3a"), hexc("2a1d14"), hexc("5a6a7a"), hexc("22222c"), extra="helmet")
human("candy_0", hexc("ffe0f0"), hexc("ff5fb0"), hexc("8fe8ff"), hexc("ff9ad5"))
human("candy_1", hexc("fff0c8"), hexc("7a4aff"), hexc("ffe36b"), hexc("b39cff"))


# ---------------------------------------------------------------- Vierbeiner

def cow(name, body, spot, snout=hexc("ffa8b8"), horn=hexc("f2e6c0"), hump=False, crown=False, spots=True):
    s = Sheet(24, 16)
    for f in range(4):
        s.frame(f)
        by = 4
        # Beine
        legc = tuple(max(0, v - 40) if i < 3 else v for i, v in enumerate(body))
        if f == 3:
            for lx in (3, 7, 14, 18):
                s.rect(lx, 11, 2, 3, legc)
        else:
            off = 1 if f == 1 else 0
            s.rect(4 + off, 11, 2, 4, legc); s.rect(7 - off, 11, 2, 4, legc)
            s.rect(13 + off, 11, 2, 4, legc); s.rect(16 - off, 11, 2, 4, legc)
            for lx in (4 + off, 7 - off, 13 + off, 16 - off):
                s.rect(lx, 14, 2, 1, hexc("2a2230"))
        # Körper
        s.rect(3, by, 16, 7, body)
        if hump:
            s.rect(7, 1, 6, 3, body); s.rect(8, 0, 4, 1, body)
        if spots:
            for (sx, sy, w, h) in ((5, 5, 3, 2), (11, 4, 3, 3), (15, 7, 2, 2), (8, 8, 2, 2)):
                s.rect(sx, sy, w, h, spot)
        s.rect(10, 11, 2, 1, snout)  # Euter
        # Schwanz
        s.rect(2, 4, 1, 4, legc); s.px(1, 8, spot)
        # Kopf
        if f == 2:  # schaut in die Kamera
            s.rect(16, 1, 7, 8, body)
            s.rect(17, 6, 5, 3, snout)
            s.px(18, 7, hexc("402030")); s.px(20, 7, hexc("402030"))
            s.rect(16, 3, 2, 2, hexc("ffffff")); s.rect(21, 3, 2, 2, hexc("ffffff"))
            s.px(17, 4, hexc("101010")); s.px(21, 4, hexc("101010"))
            s.px(16, 0, horn); s.px(22, 0, horn)
        else:
            s.rect(17, 2, 5, 6, body)
            s.rect(20, 5, 3, 3, snout)
            eye = hexc("ffffff") if f == 3 else hexc("101010")
            s.px(19, 3, eye)
            if f == 3:
                s.px(19, 4, hexc("101010"))
            s.px(17, 1, horn); s.px(20, 1, horn)
            s.px(16, 3, legc)
        if crown:
            for cx in (17, 19, 21):
                s.px(cx, 0 if f != 2 else 0, hexc("ffd23a"))
            s.rect(17, 1 if f != 2 else 0, 5, 1, hexc("ffd23a"))
    s.outline().save(name)


cow("cow", hexc("f8f6f0"), hexc("1c1820"))
cow("golden_cow", hexc("ffd23a"), hexc("e09a10"), snout=hexc("fff0a0"), horn=hexc("fff6c8"))
cow("giant_cow", hexc("f8f6f0"), hexc("6a2a8a"), crown=True)
cow("camel", hexc("d8a860"), hexc("c09048"), hump=True, spots=False, horn=hexc("d8a860"))
cow("gummy_bear_cow", hexc("ff6fa8", 230), hexc("ff9fc8", 230), snout=hexc("ffd0e0"), spots=True)


def dog(name, body, ear, cat=False):
    s = Sheet(18, 13)
    for f in range(4):
        s.frame(f)
        off = 1 if f == 1 else 0
        legc = tuple(max(0, v - 40) if i < 3 else v for i, v in enumerate(body))
        if f == 3:
            s.rect(2, 9, 1, 3, legc); s.rect(13, 9, 1, 3, legc)
        else:
            for lx in (3 + off, 5 - off, 11 + off, 13 - off):
                s.rect(lx, 9, 1, 3, legc)
        s.rect(2, 5, 12, 4, body)
        # Kopf
        s.rect(12, 2, 5, 5, body)
        if cat:
            s.px(12, 1, body); s.px(16, 1, body)
            s.rect(3, 1, 1, 4, body)  # Schwanz hoch
            s.px(2, 0 if f != 1 else 1, body)
        else:
            s.rect(11, 2, 2, 4, ear)
            s.rect(1, 3 - off, 1, 3, body)
            s.px(17, 5, hexc("101010"))
        eye = hexc("ffffff") if f in (2, 3) else hexc("101010")
        s.px(15, 3, eye)
        if f in (2, 3):
            s.px(15, 4, hexc("101010"))
        if f == 2 and not cat:
            s.px(16, 6, hexc("ff7090"))  # Zunge
    s.outline().save(name)


dog("dog", hexc("b8763a"), hexc("6b3f1c"))
dog("cat", hexc("ff9a3a"), hexc("ff9a3a"), cat=True)


def bird():
    s = Sheet(12, 10)
    for f in range(4):
        s.frame(f)
        s.rect(3, 4, 6, 3, hexc("f5f5f5"))
        s.rect(8, 3, 3, 3, hexc("f5f5f5"))
        s.px(11, 4, hexc("ffb020"))
        s.px(9, 4, hexc("101010"))
        wing = hexc("d0d0e0")
        if f % 2 == 0:
            s.rect(4, 1, 3, 3, wing)
        else:
            s.rect(4, 7, 3, 2, wing)
        s.rect(1, 4, 2, 2, hexc("d0d0e0"))
    s.outline().save("bird")


bird()


def car(name, body, window=hexc("9fdcff"), stripe=None, star=False):
    s = Sheet(28, 14)
    for f in range(4):
        s.frame(f)
        dy = -1 if f == 2 else 0
        s.rect(2, 6 + dy, 24, 5, body)
        s.rect(7, 2 + dy, 13, 5, body)
        s.rect(9, 3 + dy, 4, 3, window); s.rect(14, 3 + dy, 4, 3, window)
        if stripe:
            s.rect(2, 8 + dy, 24, 1, stripe)
        if star:
            s.px(18, 8 + dy, hexc("ffffff")); s.px(17, 8 + dy, hexc("ffffff")); s.px(19, 8 + dy, hexc("ffffff")); s.px(18, 7 + dy, hexc("ffffff"))
        s.px(25, 7 + dy, hexc("ffe36b"))  # Scheinwerfer
        s.px(2, 7 + dy, hexc("ff4040"))
        wy = 10 if f != 3 else 11
        for wx in (5, 19):
            s.rect(wx, wy, 4, 3, hexc("202028"))
            s.px(wx + (1 if f % 2 == 0 else 2), wy + 1, hexc("9090a0"))
    s.outline().save(name)


car("car_0", hexc("e8454f"))
car("car_1", hexc("3f86f2"))
car("car_2", hexc("ffcf3a"))
car("jeep", hexc("5a6a3a"), window=hexc("b0c890"), star=True)
car("candy_car", hexc("ff8fd0"), window=hexc("fff0a0"), stripe=hexc("ffffff"))


def robot(name, body, eye, small=False):
    s = Sheet(16, 20)
    for f in range(4):
        s.frame(f)
        off = 1 if f == 1 else 0
        if small:
            s.ellipse(8, 11, 5, 5, body)
            s.rect(6, 9, 4, 2, hexc("202028")); s.px(7 + off, 9, eye); s.px(7 + off, 10, eye)
            s.rect(7, 4, 2, 2, body); s.px(8, 3, eye)
            s.rect(4, 16, 2, 2, body); s.rect(10, 16, 2, 2, body)
        else:
            s.rect(4, 13, 3, 5, body); s.rect(9, 13, 3, 5, body)
            s.rect(3, 6, 10, 7, body)
            s.rect(5, 8, 6, 3, hexc("d0d0e0"))
            s.px(7, 9, hexc("40c0ff")); s.px(8, 9, hexc("40c0ff"))
            s.rect(4, 1, 8, 5, body)
            s.rect(5, 2, 6, 2, hexc("202028"))
            s.px(6 + off, 2, eye); s.px(9 + off, 2, eye)
            s.px(8, 0, eye)
            if f == 2:
                s.rect(0, 5, 3, 2, body); s.rect(13, 5, 3, 2, body)
                s.px(0, 4, hexc("ffe36b")); s.px(15, 4, hexc("ffe36b"))
            else:
                s.rect(1, 7, 2, 5, body); s.rect(13, 7, 2, 5, body)
    s.outline().save(name)


robot("robot", hexc("9aa0b0"), hexc("ff3040"))
robot("droid", hexc("c0c8d8"), hexc("40ff80"), small=True)


def penguin():
    s = Sheet(14, 16)
    for f in range(4):
        s.frame(f)
        tilt = (-1 if f == 1 else 0)
        s.ellipse(7 + tilt * 0.5, 9, 5, 6, hexc("22222c"))
        s.ellipse(7 + tilt * 0.5, 10, 3, 4.5, hexc("f5f5f5"))
        s.px(5, 5, hexc("ffffff")); s.px(9, 5, hexc("ffffff"))
        s.px(5, 6, hexc("101010")); s.px(9, 6, hexc("101010"))
        s.rect(6, 7, 3, 1, hexc("ffb020"))
        s.rect(4, 15, 2, 1, hexc("ffb020")); s.rect(8, 15, 2, 1, hexc("ffb020"))
        if f in (2, 3):
            s.rect(0, 4, 2, 4, hexc("22222c")); s.rect(12, 4, 2, 4, hexc("22222c"))
        else:
            s.rect(1, 8, 2, 4, hexc("22222c")); s.rect(11, 8, 2, 4, hexc("22222c"))
    s.outline().save("penguin")


penguin()


def cactus():
    s = Sheet(14, 20)
    g = hexc("4fb84a")
    for f in range(4):
        s.frame(f)
        off = 1 if f == 1 else 0
        s.rect(5, 4, 5, 13, g)
        if f in (2, 3):
            s.rect(1, 3, 2, 5, g); s.rect(12, 3, 2, 5, g)
        else:
            s.rect(1, 7, 2, 4, g); s.rect(2, 10, 3, 1, g); s.rect(12, 6, 2, 4, g); s.rect(10, 9, 2, 1, g)
        s.px(7, 2, hexc("ff5fb0")); s.px(6, 3, hexc("ff5fb0")); s.px(8, 3, hexc("ff5fb0"))
        s.px(6, 7, hexc("101010")); s.px(8, 7, hexc("101010"))
        s.px(7, 9, hexc("101010") if f in (2, 3) else hexc("2f8a30"))
        s.rect(5 + off, 17, 2, 2, hexc("2f8a30")); s.rect(8 - off, 17, 2, 2, hexc("2f8a30"))
        for sp in ((5, 6), (9, 12), (6, 14)):
            s.px(sp[0], sp[1], hexc("e8ffd0"))
    s.outline().save("cactus_being")


cactus()


def crystal():
    s = Sheet(14, 18)
    for f in range(4):
        s.frame(f)
        c1, c2 = hexc("9fe8ff", 235), hexc("e0f8ff", 245)
        for y in range(16):
            w = int(6 - abs(y - 7) * 0.8)
            if w > 0:
                s.rect(7 - w, y + 1, w * 2, 1, c1)
        s.rect(6, 3, 2, 8, c2)
        sp = [(4, 4), (9, 7), (6, 12), (8, 2)][f]
        s.px(sp[0], sp[1], hexc("ffffff"))
    s.outline(hexc("2a5a8a")).save("ice_crystal")


crystal()

# ---------------------------------------------------------------- UFOs


def ufo(name, w, h, hull, band, dome, lights, spots=None, alien=hexc("6ae05a")):
    s = Sheet(w, h, 2)
    for f in range(2):
        s.frame(f)
        cx = w / 2
        s.ellipse(cx, h * 0.33, w * 0.22, h * 0.3, dome)
        s.ellipse(cx, h * 0.36, w * 0.08, h * 0.14, alien)
        s.px(int(cx) - 1, int(h * 0.34), hexc("101010")); s.px(int(cx) + 1, int(h * 0.34), hexc("101010"))
        s.ellipse(cx, h * 0.62, w * 0.48, h * 0.2, hull)
        s.rect(int(w * 0.08), int(h * 0.6), int(w * 0.84), max(1, h // 8), band)
        if spots:
            for (sx, sy) in ((0.25, 0.55), (0.6, 0.7), (0.78, 0.55)):
                s.rect(int(w * sx), int(h * sy), max(2, w // 12), max(1, h // 10), spots)
        n = max(3, w // 6)
        for i in range(n):
            lx = int(w * 0.12 + i * (w * 0.76) / (n - 1))
            on = (i + f) % 2 == 0
            s.px(lx, int(h * 0.62), lights[0] if on else lights[1])
        s.ellipse(cx, h * 0.8, w * 0.22, h * 0.07, tuple(max(0, v - 60) if i < 3 else v for i, v in enumerate(hull)))
        # Glanz
        s.px(int(cx - w * 0.12), int(h * 0.18), hexc("ffffff"))
    s.outline().save(name)


ufo("ufo_classic", 40, 22, hexc("e8ecf4"), hexc("3a6ee8"), hexc("9fdcff", 220), (hexc("ffe36b"), hexc("3a6ee8")))
ufo("ufo_rusty", 40, 22, hexc("b07040"), hexc("6b3f1c"), hexc("c8e0b0", 220), (hexc("ff8c32"), hexc("6b3f1c")))
ufo("ufo_disco", 40, 22, hexc("b064e8"), hexc("ff5fb0"), hexc("ffd0f0", 220), (hexc("5cffea"), hexc("ffe36b")))
ufo("ufo_cow", 40, 22, hexc("f8f6f0"), hexc("ff9fc8"), hexc("c0f0ff", 220), (hexc("ffe36b"), hexc("1c1820")), spots=hexc("1c1820"))
ufo("ufo_gold", 40, 22, hexc("ffd23a"), hexc("e09a10"), hexc("fff6c8", 220), (hexc("ffffff"), hexc("e09a10")))
ufo("drone", 18, 10, hexc("d8dce8"), hexc("40c0ff"), hexc("b0e8ff", 220), (hexc("40ff80"), hexc("206040")))
ufo("patrol", 28, 15, hexc("e8454f"), hexc("f5f5f5"), hexc("ffd0d0", 220), (hexc("ffe36b"), hexc("802020")))
ufo("vacation_ufo", 40, 22, hexc("ff9fc8"), hexc("ffe36b"), hexc("fff0a0", 220), (hexc("5cffea"), hexc("ff5fb0")), alien=hexc("ffb0e0"))
ufo("beiboot", 48, 22, hexc("6a4aa0"), hexc("5cffea"), hexc("c8b0ff", 220), (hexc("5cffea"), hexc("3a2a60")))

# Mutterschiff
ms = Sheet(128, 44, 1)
ms.ellipse(64, 15, 26, 13, hexc("8a70c0"))
for i in range(5):
    ms.ellipse(46 + i * 9, 13, 3, 3, hexc("9fdcff"))
    ms.px(46 + i * 9, 13, hexc("6ae05a"))
ms.ellipse(64, 28, 62, 12, hexc("4a4660"))
ms.ellipse(64, 26, 60, 9, hexc("7a7690"))
ms.rect(8, 26, 112, 2, hexc("5cffea"))
for i in range(15):
    ms.px(10 + i * 8, 29, hexc("ffe36b") if i % 2 else hexc("ff5fb0"))
ms.ellipse(64, 37, 24, 4, hexc("5cffea"))
ms.outline().save("mothership")

# ---------------------------------------------------------------- Icons (16x16)


def icon(name, draw):
    s = Sheet(16, 16, 1)
    draw(s)
    s.outline().save(name, ICO)


def coin(s):
    s.ellipse(8, 8, 6, 6, hexc("ffd23a")); s.ellipse(8, 8, 4, 4, hexc("ffe98a")); s.rect(7, 5, 2, 6, hexc("e09a10"))


def biomass(s):
    s.ellipse(8, 9, 6, 5, hexc("6ae05a")); s.ellipse(6, 7, 2, 2, hexc("b8ff9a")); s.px(10, 10, hexc("2f8a30")); s.px(11, 3, hexc("6ae05a")); s.px(4, 3, hexc("6ae05a"))


def data(s):
    s.rect(3, 3, 10, 10, hexc("40c0ff")); s.rect(5, 5, 6, 6, hexc("1a4a8a"))
    for i in range(4):
        s.px(1, 4 + i * 2, hexc("40c0ff")); s.px(14, 4 + i * 2, hexc("40c0ff")); s.px(4 + i * 2, 1, hexc("40c0ff")); s.px(4 + i * 2, 14, hexc("40c0ff"))
    s.px(7, 7, hexc("9fe8ff")); s.px(8, 8, hexc("9fe8ff"))


def star(s, c=hexc("ffd23a")):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 7 if i % 2 == 0 else 3
        pts.append((8 + math.cos(a) * r, 8 + math.sin(a) * r))
    for y in range(16):
        for x in range(16):
            # Punkt-in-Polygon
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]; xj, yj = pts[j]
                if ((yi > y + 0.5) != (yj > y + 0.5)) and (x + 0.5 < (xj - xi) * (y + 0.5 - yi) / (yj - yi + 1e-9) + xi):
                    inside = not inside
                j = i
            if inside:
                s.px(x, y, c)


def bolt(s, c=hexc("ffe36b")):
    for (x, y) in ((9, 1), (8, 2), (8, 3), (7, 4), (7, 5), (6, 6), (6, 7), (7, 7), (8, 7), (9, 7), (10, 7), (9, 8), (9, 9), (8, 10), (8, 11), (7, 12), (7, 13), (6, 14)):
        s.px(x, y, c); s.px(x + 1, y, c)


def skillpoint(s):
    s.ellipse(8, 8, 7, 7, hexc("b064e8")); star(s, hexc("ffe0ff"))


def ruf(s):
    s.ellipse(8, 8, 7, 7, hexc("3a2a80")); star(s, hexc("5cffea"))


def magnet(s):
    s.rect(3, 3, 3, 9, hexc("e8454f")); s.rect(10, 3, 3, 9, hexc("3f86f2")); s.rect(3, 11, 10, 3, hexc("9aa0b0"))
    s.rect(3, 2, 3, 2, hexc("f5f5f5")); s.rect(10, 2, 3, 2, hexc("f5f5f5"))


def rng(s):
    s.ellipse(8, 8, 7, 7, hexc("47c96b")); s.ellipse(8, 8, 5, 5, (0, 0, 0, 0)); s.ellipse(8, 8, 2, 2, hexc("47c96b"))


def multi(s):
    for (x, y) in ((4, 5), (11, 5), (8, 11)):
        s.ellipse(x, y, 3, 3, hexc("5cffea"))


def battery(s):
    s.rect(3, 4, 10, 9, hexc("47c96b")); s.rect(6, 2, 4, 2, hexc("9aa0b0")); s.rect(5, 6, 6, 5, hexc("b8ff9a"))


def sun(s):
    s.ellipse(8, 8, 4, 4, hexc("ffd23a"))
    for i in range(8):
        a = i * math.pi / 4
        s.px(int(8 + math.cos(a) * 6.5), int(8 + math.sin(a) * 6.5), hexc("ff8c32"))


def lure(s):
    s.rect(3, 6, 10, 7, hexc("ffcf3a")); s.rect(3, 4, 6, 2, hexc("ffcf3a"))
    s.px(5, 8, hexc("e09a10")); s.px(9, 10, hexc("e09a10")); s.px(11, 7, hexc("e09a10"))


def flask(s, c=hexc("5cffea")):
    s.rect(6, 1, 4, 5, hexc("d0e8f0")); s.ellipse(8, 10, 6, 5, hexc("d0e8f0")); s.ellipse(8, 11, 5, 3.5, c); s.px(6, 10, hexc("ffffff"))


def dna(s):
    for y in range(1, 15):
        x1 = int(8 + math.sin(y * 0.6) * 4); x2 = int(8 - math.sin(y * 0.6) * 4)
        s.px(x1, y, hexc("6ae05a")); s.px(x2, y, hexc("ff5fb0"))
        if y % 3 == 0:
            for x in range(min(x1, x2), max(x1, x2)):
                s.px(x, y, hexc("d0d0e0"))


def trophy(s):
    s.rect(4, 2, 8, 6, hexc("ffd23a")); s.rect(2, 3, 2, 3, hexc("ffd23a")); s.rect(12, 3, 2, 3, hexc("ffd23a"))
    s.rect(7, 8, 2, 3, hexc("e09a10")); s.rect(4, 11, 8, 3, hexc("e09a10"))


def lock(s):
    s.rect(4, 7, 8, 7, hexc("9aa0b0")); s.rect(5, 3, 1, 4, hexc("9aa0b0")); s.rect(10, 3, 1, 4, hexc("9aa0b0")); s.rect(5, 2, 6, 1, hexc("9aa0b0"))
    s.rect(7, 9, 2, 3, hexc("303040"))


def paint(s):
    s.rect(3, 3, 8, 5, hexc("ff5fb0")); s.rect(11, 5, 2, 4, hexc("9aa0b0")); s.rect(7, 8, 2, 6, hexc("6b3f1c"))


def clock(s):
    s.ellipse(8, 8, 7, 7, hexc("f5f5f5")); s.rect(7, 3, 2, 6, hexc("303040")); s.rect(8, 7, 4, 2, hexc("303040"))


def double(s):
    s.rect(2, 4, 6, 8, hexc("3f86f2")); s.rect(8, 4, 6, 8, hexc("e8454f")); s.px(5, 7, hexc("ffffff")); s.px(11, 7, hexc("ffffff"))


def charge(s):
    s.ellipse(8, 8, 7, 7, hexc("b064e8")); bolt(s, hexc("ffffff"))


def eye(s):
    s.ellipse(8, 8, 7, 4, hexc("f5f5f5")); s.ellipse(8, 8, 3, 3, hexc("3f86f2")); s.ellipse(8, 8, 1.5, 1.5, hexc("101010"))


def beam(s):
    for y in range(4, 16):
        w = 1 + (y - 4) // 3
        s.rect(8 - w, y, w * 2, 1, hexc("6ae05a", 200))
    s.ellipse(8, 3, 6, 2.5, hexc("d8dce8"))


def alien_face(c):
    def d(s):
        s.ellipse(8, 8, 6, 7, c)
        s.ellipse(5.5, 8, 2, 3, hexc("101010")); s.ellipse(10.5, 8, 2, 3, hexc("101010"))
        s.px(5, 7, hexc("ffffff")); s.px(10, 7, hexc("ffffff"))
        s.rect(7, 12, 2, 1, hexc("303040"))
    return d


def planet(c1, c2):
    def d(s):
        s.ellipse(8, 8, 7, 7, c1); s.ellipse(6, 6, 3, 2, c2); s.ellipse(10, 11, 2, 1.5, c2)
    return d


def from_sprite(name, frame_w, scale_to=16):
    img = Image.open(os.path.join(SPR, name + ".png")).crop((0, 0, frame_w, Image.open(os.path.join(SPR, name + ".png")).size[1]))
    img.thumbnail((scale_to, scale_to), Image.NEAREST)
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    out.paste(img, ((16 - img.size[0]) // 2, (16 - img.size[1]) // 2))
    return out


icon("coin", coin); icon("biomass", biomass); icon("data", data); icon("star", star); icon("energy", bolt)
icon("skillpoint", skillpoint); icon("ruf", ruf); icon("power", magnet); icon("range", rng); icon("speed", bolt)
icon("multi", multi); icon("crit", lambda s: star(s, hexc("ff5fb0"))); icon("lure", lure); icon("battery", battery)
icon("solar", sun); icon("research", flask); icon("dna", dna); icon("trophy", trophy); icon("lock", lock)
icon("paint", paint); icon("clock", clock); icon("double", double); icon("charge", charge); icon("eye", eye)
icon("beam", beam); icon("magnet", magnet)
for nm, col in (("zorg", "6ae05a"), ("blib", "40c0ff"), ("xul", "ff9fc8"), ("glorp", "ffcf3a"), ("quix", "b064e8")):
    icon("crew_" + nm, alien_face(hexc(col)))
for nm, a, b in (("earth", "3f86f2", "47c96b"), ("desert", "e0b060", "c08040"), ("ice", "d0f0ff", "9fdcff"),
                 ("robot", "9aa0b0", "5a6a7a"), ("candy", "ff8fd0", "fff0a0"), ("mini", "b064e8", "5cffea")):
    icon("planet_" + nm, planet(hexc(a), hexc(b)))
for nm, fw in (("drone", 18), ("patrol", 28), ("beiboot", 48), ("cow", 24), ("dog", 18), ("bird", 12), ("car_0", 28),
               ("spy", 14), ("celebrity", 14), ("robot", 16), ("jeep", 28), ("giant_cow", 24), ("golden_cow", 24), ("human_0", 14)):
    from_sprite(nm, fw).save(os.path.join(ICO, "t_" + nm + ".png"))
# Laser-Icon
las = Sheet(16, 16, 1)
las.rect(7, 0, 2, 16, hexc("ff3040")); las.rect(6, 0, 1, 16, hexc("ff9aa0")); las.rect(9, 0, 1, 16, hexc("ff9aa0"))
las.save("laser", ICO)
# Partikel
p = Image.new("RGBA", (4, 4), (255, 255, 255, 255)); p.save(os.path.join(SPR, "pixel.png"))
sp = Sheet(7, 7, 1)
sp.rect(3, 0, 1, 7, hexc("ffffff")); sp.rect(0, 3, 7, 1, hexc("ffffff")); sp.px(3, 3, hexc("ffffff"))
sp.save("sparkle")
print("ok", len(os.listdir(SPR)), "sprites,", len(os.listdir(ICO)), "icons")

# Deko-Icons: UFO-Skins (erstes Frame) und Strahlfarben
for nm in ("classic", "rusty", "disco", "cow", "gold"):
    from_sprite("ufo_" + nm, 40).save(os.path.join(ICO, "skin_" + nm + ".png"))
for nm, col in (("green", "6ae05a"), ("pink", "ff6fc0"), ("blue", "40c0ff"), ("gold", "ffd23a"), ("rainbow", None)):
    s = Sheet(16, 16, 1)
    s.ellipse(8, 3, 6, 2.5, hexc("d8dce8"))
    rainbow = ["ff4040", "ff9a3a", "ffe36b", "6ae05a", "40c0ff", "b064e8"]
    for y in range(5, 16):
        w = 1 + (y - 4) // 3
        c = hexc(rainbow[(y - 5) % 6]) if col is None else hexc(col, 220)
        s.rect(8 - w, y, w * 2, 1, c)
    s.outline().save("beam_" + nm, ICO)
print("deko ok")
