#!/usr/bin/env python3
# Uygulamadaki ayet ve hadis içeriğini kaynaklarından çeker, assets/icerik/ altına JSON olarak yazar.
#  - Ayetler: AlQuran Cloud (Arapça: quran-uthmani, Türkçe: tr.diyanet = Diyanet İşleri meali)
#  - Hadisler: HadeethEnc (Hadis Ansiklopedisi), sadece "Sahih" ve Buhârî/Müslim kaynaklı olanlar
# GitHub Actions'ta "İçerik üret" işiyle çalışır; elle değiştirmeye gerek yok.

import json
import os
import re
import sys
import time
import unicodedata
import urllib.request

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CIKTI = os.path.join(KOK, "assets", "icerik")


def besmelesiz(sure, no, metin):
    """Sûrelerin 1. ayetinin başındaki besmele ayetten sayılmaz (Fâtiha hariç).
    Kaynak besmeleyi farklı harf biçimleriyle yazabildiği için ilk dört kelime atılır."""
    metin = metin.replace("\ufeff", "").strip()
    if no == 1 and sure != 1 and metin.startswith("بِسْمِ"):
        return " ".join(metin.split()[4:])
    return metin

SURELER = [
    "Fâtiha", "Bakara", "Âl-i İmrân", "Nisâ", "Mâide", "En'âm", "A'râf", "Enfâl", "Tevbe", "Yûnus",
    "Hûd", "Yûsuf", "Ra'd", "İbrâhîm", "Hicr", "Nahl", "İsrâ", "Kehf", "Meryem", "Tâhâ",
    "Enbiyâ", "Hac", "Mü'minûn", "Nûr", "Furkân", "Şuarâ", "Neml", "Kasas", "Ankebût", "Rûm",
    "Lokmân", "Secde", "Ahzâb", "Sebe'", "Fâtır", "Yâsîn", "Sâffât", "Sâd", "Zümer", "Mü'min",
    "Fussilet", "Şûrâ", "Zuhruf", "Duhân", "Câsiye", "Ahkâf", "Muhammed", "Fetih", "Hucurât", "Kâf",
    "Zâriyât", "Tûr", "Necm", "Kamer", "Rahmân", "Vâkıa", "Hadîd", "Mücâdele", "Haşr", "Mümtehine",
    "Saf", "Cuma", "Münâfikûn", "Teğâbün", "Talâk", "Tahrîm", "Mülk", "Kalem", "Hâkka", "Meâric",
    "Nûh", "Cin", "Müzzemmil", "Müddessir", "Kıyâme", "İnsân", "Mürselât", "Nebe'", "Nâziât", "Abese",
    "Tekvîr", "İnfitâr", "Mutaffifîn", "İnşikâk", "Bürûc", "Târık", "A'lâ", "Gâşiye", "Fecr", "Beled",
    "Şems", "Leyl", "Duhâ", "İnşirâh", "Tîn", "Alak", "Kadr", "Beyyine", "Zilzâl", "Âdiyât",
    "Kâria", "Tekâsür", "Asr", "Hümeze", "Fîl", "Kureyş", "Mâûn", "Kevser", "Kâfirûn", "Nasr",
    "Tebbet", "İhlâs", "Felak", "Nâs",
]
assert len(SURELER) == 114


def getir(adres, deneme=4):
    """Adresi indirir, JSON olarak döndürür; geçici hatalarda birkaç kez dener."""
    for i in range(deneme):
        try:
            istek = urllib.request.Request(adres, headers={"User-Agent": "EzanVakitlerim/1.2 (github.com/Seyfettin7910/EZAN-VAKITLERIM)"})
            with urllib.request.urlopen(istek, timeout=30) as y:
                return json.loads(y.read().decode("utf-8"))
        except Exception as hata:
            if i == deneme - 1:
                raise
            print(f"  tekrar deneniyor ({hata}): {adres}", file=sys.stderr)
            time.sleep(2 + 2 * i)


def ayetleri_uret():
    """secme_ayetler.txt'deki her grubu Arapça + Diyanet meali olarak indirir."""
    gruplar = []
    with open(os.path.join(KOK, "tool", "secme_ayetler.txt"), encoding="utf-8") as f:
        for satir in f:
            satir = satir.strip()
            if not satir or satir.startswith("#"):
                continue
            ref, konu = [p.strip() for p in satir.split("|", 1)]
            sure, aralik = ref.split(":")
            sure = int(sure)
            bas, son = (aralik.split("-") + [aralik])[:2]
            bas, son = int(bas), int(son)
            adet = son - bas + 1
            j = getir(f"https://api.alquran.cloud/v1/surah/{sure}/editions/quran-uthmani,tr.diyanet?offset={bas - 1}&limit={adet}")
            baskilar = {b["edition"]["identifier"]: b["ayahs"] for b in j["data"]}
            ar, tr = baskilar["quran-uthmani"], baskilar["tr.diyanet"]
            if len(ar) != adet or len(tr) != adet:
                raise SystemExit(f"{ref}: {adet} ayet beklendi, {len(ar)}/{len(tr)} geldi")
            ayetler = []
            for a, t in zip(ar, tr):
                no = a["numberInSurah"]
                if no != t["numberInSurah"]:
                    raise SystemExit(f"{ref}: ayet numaraları uyuşmuyor")
                arapca = besmelesiz(sure, no, a["text"])
                ayetler.append({"no": no, "ar": arapca, "tr": t["text"].strip()})
            if [x["no"] for x in ayetler] != list(range(bas, son + 1)):
                raise SystemExit(f"{ref}: yanlış ayetler geldi")
            gruplar.append({"sure": sure, "ad": SURELER[sure - 1], "bas": bas, "son": son, "konu": konu, "ayetler": ayetler})
            print(f"ayet {SURELER[sure - 1]} {bas}-{son} ({adet})")
            time.sleep(0.3)
    return gruplar


def sade(s):
    """Karşılaştırma için harfleri sadeleştirir: küçük harf, şapkasız."""
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c))
    return s.lower().replace("ı", "i")


BASKA_KAYNAKLAR = ("ahmed", "darimi", "tirmizi", "ebu davud", "ebû davud", "nesai", "ibn mace", "ibni mace", "malik", "hakim", "beyhaki", "taberani", "edeb")


def kabul_mu(h):
    """Sadece "Sahih Hadis" dereceli ve yalnızca Buhârî/Müslim kaynaklı hadisler alınır."""
    derece, kaynak = sade(h.get("grade")).strip(), sade(h.get("attribution"))
    if derece != "sahih hadis":
        return False
    if any(b in kaynak for b in BASKA_KAYNAKLAR):  # başka kitaplar da karışmışsa alma
        return False
    return "muttefek" in kaynak or "buhari" in kaynak or "muslim" in kaynak


def kaynak_yazisi(attribution):
    a = sade(attribution)
    buhari, muslim = "buhari" in a, "muslim" in a
    if "muttefek" in a or (buhari and muslim):
        return "Buhârî ve Müslim"
    return "Buhârî" if buhari else "Müslim"


def hadisleri_uret(kategoriler=(5, 1)):
    """Kategorilerdeki hadisleri tek tek indirir, uygun olanları saklar."""
    kimlikler = []
    for k in kategoriler:
        sayfa = 1
        while True:
            j = getir(f"https://hadeethenc.com/api/v1/hadeeths/list/?language=tr&category_id={k}&page={sayfa}&per_page=100")
            kimlikler += [d["id"] for d in j["data"]]
            if sayfa >= int(j["meta"]["last_page"]):
                break
            sayfa += 1
    kimlikler = list(dict.fromkeys(kimlikler))
    print(f"{len(kimlikler)} hadis incelenecek")
    hadisler = []
    for i, kimlik in enumerate(kimlikler):
        try:
            h = getir(f"https://hadeethenc.com/api/v1/hadeeths/one/?language=tr&id={kimlik}")
        except Exception as hata:
            print(f"  atlandı {kimlik}: {hata}", file=sys.stderr)
            continue
        if kabul_mu(h):
            hadisler.append({
                "id": h["id"],
                "baslik": (h.get("title") or "").strip(),
                "metin": re.sub(r"\s+\n", "\n", (h.get("hadeeth") or "").strip()),
                "aciklama": (h.get("explanation") or "").strip(),
                "kaynak": kaynak_yazisi(h.get("attribution")),
                "derece": (h.get("grade") or "").strip(),
            })
        if i % 50 == 0:
            print(f"  {i}/{len(kimlikler)} incelendi, {len(hadisler)} kabul")
        time.sleep(0.15)
    return hadisler


def main():
    os.makedirs(CIKTI, exist_ok=True)
    ayetler = ayetleri_uret()
    with open(os.path.join(CIKTI, "ayetler.json"), "w", encoding="utf-8") as f:
        json.dump(ayetler, f, ensure_ascii=False, indent=1)
    hadisler = hadisleri_uret()
    if len(hadisler) < 30:
        raise SystemExit(f"çok az hadis kabul edildi: {len(hadisler)}")
    with open(os.path.join(CIKTI, "hadisler.json"), "w", encoding="utf-8") as f:
        json.dump(hadisler, f, ensure_ascii=False, indent=1)
    print(f"bitti: {len(ayetler)} ayet grubu, {len(hadisler)} hadis")


if __name__ == "__main__":
    main()
