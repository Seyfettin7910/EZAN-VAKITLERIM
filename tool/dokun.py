#!/usr/bin/env python3
# Emülatör testi için: ekran dökümünde (uiautomator) yazısı verilen öğenin ortasını "x y" olarak yazar.
# Kullanım: dokun.py dokum.xml "Kıble" [alt]   ("alt": eşleşenlerden en alttakini seç, ör. menü sekmesi)
import re
import sys
import xml.etree.ElementTree as ET

dosya, aranan = sys.argv[1], sys.argv[2]
alttaki = len(sys.argv) > 3 and sys.argv[3] == "alt"
adaylar = []
for d in ET.parse(dosya).iter("node"):
    yazi = (d.get("content-desc") or "") + "\n" + (d.get("text") or "")
    if aranan in yazi:
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", d.get("bounds")))
        adaylar.append(((x1 + x2) // 2, (y1 + y2) // 2, (x2 - x1) * (y2 - y1)))
if not adaylar:
    sys.exit(1)
x, y, _ = max(adaylar, key=lambda a: a[1]) if alttaki else min(adaylar, key=lambda a: a[2])
print(x, y)
