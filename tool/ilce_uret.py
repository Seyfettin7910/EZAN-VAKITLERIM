#!/usr/bin/env python3
# Türkiye'nin il ve ilçelerini merkez koordinatlarıyla Wikidata'dan çeker, assets/veri/ilceler.json'a yazar.
# GitHub Actions'ta "İlçe verisi üret" işiyle çalışır.

import json
import os
import re
import sys
import unicodedata
import urllib.parse
import urllib.request

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SORGU = """
SELECT ?ilce ?ilceAdi ?il ?ilAdi ?plaka ?koordinat WHERE {
  ?ilce wdt:P31 wd:Q1147395 .
  ?ilce wdt:P131 ?il .
  ?il wdt:P31 wd:Q48336 .
  OPTIONAL { ?il wdt:P395 ?plaka . }
  OPTIONAL { ?ilce wdt:P625 ?koordinat . }
  FILTER NOT EXISTS { ?ilce wdt:P576 ?kapanis . }
  ?ilce rdfs:label ?ilceAdi . FILTER(LANG(?ilceAdi) = "tr")
  ?il rdfs:label ?ilAdi . FILTER(LANG(?ilAdi) = "tr")
}
"""


def sade(s):
    s = unicodedata.normalize("NFKD", s).replace("ı", "i").replace("İ", "i")
    return "".join(c for c in s if not unicodedata.combining(c)).lower()


def iller_dart():
    """lib/veri/iller.dart'taki 81 ili (plaka, ad) okur; eşleştirme bu adlara göre yapılır."""
    metin = open(os.path.join(KOK, "lib", "veri", "iller.dart"), encoding="utf-8").read()
    return [(int(p), ad, float(e), float(b)) for p, ad, e, b in re.findall(r"Il\((\d+), '([^']+)', ([\d.]+), ([\d.]+)\)", metin)]


def main():
    adres = "https://query.wikidata.org/sparql?" + urllib.parse.urlencode({"query": SORGU, "format": "json"})
    istek = urllib.request.Request(adres, headers={
        "User-Agent": "EzanVakitlerim/1.2 (github.com/Seyfettin7910/EZAN-VAKITLERIM)",
        "Accept": "application/sparql-results+json",
    })
    with urllib.request.urlopen(istek, timeout=120) as y:
        satirlar = json.loads(y.read().decode("utf-8"))["results"]["bindings"]
    print(f"{len(satirlar)} satır geldi")

    iller = iller_dart()
    ad_ile = {sade(ad): (p, ad, e, b) for p, ad, e, b in iller}
    sonuc = {p: {"plaka": p, "il": ad, "enlem": e, "boylam": b, "ilceler": {}} for p, ad, e, b in iller}
    eslesmeyen = set()
    koordinatsiz = []
    for s in satirlar:
        il_adi = re.sub(r"\s+ili$", "", s["ilAdi"]["value"]).strip()
        plaka = s.get("plaka", {}).get("value")
        hedef = sonuc.get(int(plaka)) if plaka and plaka.isdigit() and int(plaka) in sonuc else None
        if hedef is None and sade(il_adi) in ad_ile:
            hedef = sonuc[ad_ile[sade(il_adi)][0]]
        if hedef is None:
            eslesmeyen.add(il_adi)
            continue
        ilce_adi = re.sub(r"\s+ilçesi$", "", s["ilceAdi"]["value"]).strip()
        if "koordinat" not in s:
            koordinatsiz.append(f"{hedef['il']}/{ilce_adi}")
            continue
        m = re.match(r"Point\(([-\d.]+) ([-\d.]+)\)", s["koordinat"]["value"])
        boylam, enlem = float(m.group(1)), float(m.group(2))
        # Türkiye sınırları dışında bir koordinat varsa yanlıştır
        if not (35.5 <= enlem <= 42.5 and 25.5 <= boylam <= 45.0):
            koordinatsiz.append(f"{hedef['il']}/{ilce_adi} (sınır dışı)")
            continue
        hedef["ilceler"].setdefault(ilce_adi, (round(enlem, 4), round(boylam, 4)))

    liste = []
    toplam = 0
    for p in sorted(sonuc):
        il = sonuc[p]
        ilceler = sorted(il["ilceler"].items(), key=lambda x: sade(x[0]))
        toplam += len(ilceler)
        liste.append({"plaka": p, "il": il["il"], "ilceler": [{"ad": a, "enlem": e, "boylam": b} for a, (e, b) in ilceler]})
        if not ilceler:
            print(f"UYARI: {il['il']} için ilçe yok")
    print(f"{len(liste)} il, {toplam} ilçe")
    if eslesmeyen:
        print("eşleşmeyen iller:", ", ".join(sorted(eslesmeyen)))
    if koordinatsiz:
        print("koordinatı olmayan ilçeler:", ", ".join(koordinatsiz))
    if toplam < 900:
        sys.exit(f"çok az ilçe: {toplam}")
    os.makedirs(os.path.join(KOK, "assets", "veri"), exist_ok=True)
    with open(os.path.join(KOK, "assets", "veri", "ilceler.json"), "w", encoding="utf-8") as f:
        json.dump(liste, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
