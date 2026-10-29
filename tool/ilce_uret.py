#!/usr/bin/env python3
# Türkiye'nin il ve ilçelerini OpenStreetMap idari sınırlarından çeker, assets/veri/ilceler.json'a yazar.
#  - İl = admin_level 4, ilçe = admin_level 6 (ilin sınırı içinde)
#  - İlçenin koordinatı: OSM'deki ilçe merkezi noktası (admin_centre / label), yoksa bölgenin ortası
# GitHub Actions'ta "İlçe verisi üret" işiyle çalışır.

import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UA = "EzanVakitlerim/1.2 (github.com/Seyfettin7910/EZAN-VAKITLERIM)"
SUNUCULAR = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]


def sade(s):
    s = unicodedata.normalize("NFKD", s).replace("ı", "i").replace("İ", "i")
    return "".join(c for c in s if not unicodedata.combining(c)).lower().strip()


def iller_dart():
    """lib/veri/iller.dart'taki 81 ili (plaka, ad) okur."""
    metin = open(os.path.join(KOK, "lib", "veri", "iller.dart"), encoding="utf-8").read()
    return [(int(p), ad) for p, ad in re.findall(r"Il\((\d+), '([^']+)'", metin)]


def overpass(sorgu):
    for deneme in range(6):
        sunucu = SUNUCULAR[deneme % len(SUNUCULAR)]
        try:
            veri = urllib.parse.urlencode({"data": sorgu}).encode()
            istek = urllib.request.Request(sunucu, data=veri, headers={"User-Agent": UA})
            with urllib.request.urlopen(istek, timeout=300) as y:
                return json.loads(y.read().decode("utf-8"))["elements"]
        except Exception as hata:
            print(f"  Overpass tekrar ({sunucu}): {hata}", file=sys.stderr)
            time.sleep(15 * (deneme + 1))
    raise SystemExit("Overpass'a ulaşılamadı")


def il_adi_temizle(ad):
    return re.sub(r"\s+(ili|İli)$", "", ad).strip()


def ilce_adi_temizle(ad, il):
    ad = re.sub(r"\s*\(.*?\)\s*", " ", ad)  # parantez içini at
    ad = re.sub(r"\s+(ilçesi|İlçesi|İlçe|ilçe)$", "", ad.strip())
    ad = ad.strip()
    if sade(ad) in (sade(il), sade(il) + " merkez", "merkez " + sade(il), "merkez") or "merkez" in sade(ad).split():
        return "Merkez"
    return ad


def main():
    iller = iller_dart()
    plaka_ile = {sade(ad): p for p, ad in iller}
    sonuc = {p: {"plaka": p, "il": ad, "ilceler": {}} for p, ad in iller}

    sorgu = """
[out:json][timeout:280];
area["ISO3166-1"="TR"][admin_level=2]->.tr;
rel(area.tr)["boundary"="administrative"]["admin_level"="4"]->.iller;
foreach .iller -> .il (
  .il out tags;
  .il map_to_area -> .a;
  rel(area.a)["boundary"="administrative"]["admin_level"="6"]->.ilceler;
  .ilceler out body center;
  node(r.ilceler:"admin_centre")->.m1;
  node(r.ilceler:"label")->.m2;
  (.m1; .m2;) -> .merkezler;
  .merkezler out skel;
)
"""
    ogeler = overpass(sorgu)
    print(f"{len(ogeler)} öğe geldi")

    noktalar = {o["id"]: (o["lat"], o["lon"]) for o in ogeler if o["type"] == "node"}
    gecerli_il = None
    eslesmeyen = []
    for o in ogeler:
        if o["type"] != "relation":
            continue
        etiket = o.get("tags", {})
        if etiket.get("admin_level") == "4":
            ad = il_adi_temizle(etiket.get("name:tr") or etiket.get("name", ""))
            gecerli_il = plaka_ile.get(sade(ad))
            if gecerli_il is None:
                eslesmeyen.append(ad)
            continue
        if etiket.get("admin_level") != "6" or gecerli_il is None:
            continue
        il_adi = sonuc[gecerli_il]["il"]
        ad = ilce_adi_temizle(etiket.get("name:tr") or etiket.get("name", ""), il_adi)
        if not ad:
            continue
        # İlçe merkezi noktası varsa onu, yoksa bölgenin ortasını kullan
        konum = None
        for rol in ("admin_centre", "label"):
            for uye in o.get("members", []):
                if uye.get("type") == "node" and uye.get("role") == rol and uye["ref"] in noktalar:
                    konum = noktalar[uye["ref"]]
                    break
            if konum:
                break
        if konum is None and "center" in o:
            konum = (o["center"]["lat"], o["center"]["lon"])
        if konum is None:
            continue
        sonuc[gecerli_il]["ilceler"].setdefault(ad, (round(konum[0], 4), round(konum[1], 4)))

    liste, toplam = [], 0
    for p in sorted(sonuc):
        il = sonuc[p]
        ilceler = sorted(il["ilceler"].items(), key=lambda x: (x[0] != "Merkez", sade(x[0])))
        toplam += len(ilceler)
        liste.append({"plaka": p, "il": il["il"], "ilceler": [{"ad": a, "enlem": e, "boylam": b} for a, (e, b) in ilceler]})
        print(f"{p:2d} {il['il']}: {len(ilceler)}")
    print(f"TOPLAM: {len(liste)} il, {toplam} ilçe")
    if eslesmeyen:
        print("eşleşmeyen iller:", ", ".join(eslesmeyen))
    if toplam < 950:
        sys.exit(f"çok az ilçe: {toplam}")
    os.makedirs(os.path.join(KOK, "assets", "veri"), exist_ok=True)
    with open(os.path.join(KOK, "assets", "veri", "ilceler.json"), "w", encoding="utf-8") as f:
        json.dump(liste, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
