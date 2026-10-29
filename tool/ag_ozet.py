#!/usr/bin/env python3
# Ağ denemesi için: Photon / Nominatim cevabını özetler (kaç sonuç, en yakınlar).
import json, math, sys
tur, dosya = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(dosya))
except Exception as h:
    print("okunamadı:", h); sys.exit(0)
if tur == "photon":
    f = d.get("features", [])
    print("adet", len(f))
    for x in f[:12]:
        lo, la = x["geometry"]["coordinates"]
        m = math.hypot((la - 39.9179) * 111000, (lo - 32.8628) * 85000)
        print(round(m), "m", x["properties"].get("name"), x["properties"].get("osm_value"))
else:
    print("adet", len(d))
    from collections import Counter
    print(Counter((x.get("extratags") or {}).get("religion") for x in d))
    for x in d[:15]:
        la, lo = float(x["lat"]), float(x["lon"])
        m = math.hypot((la - 39.9179) * 111000, (lo - 32.8628) * 85000)
        print(round(m), "m", repr(x.get("name")), (x.get("extratags") or {}).get("religion"), x.get("osm_type"), x.get("osm_id"))
