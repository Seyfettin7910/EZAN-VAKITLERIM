#!/bin/bash
# Emülatörde uygulamayı açar, konum seçer, sekmeleri gezer ve her ekranın görüntüsünü alır.
# GitHub Actions'taki "APK kontrol" işi (gezinti seçeneğiyle) çalıştırır.
O=/tmp/k
P=com.seyfettin.ezan_vakitlerim
D=$(dirname "$0")

# Ekran boyutu (kaydırma bunun oranlarıyla yapılır)
BOYUT=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1)
G=${BOYUT%x*}; Y=${BOYUT#*x}
echo "ekran: ${G}x${Y}"

dokun() { # yazısı $1 olan öğeye dokunur ($2 = "alt" ise en alttakine); bulursa 0 döner
  adb shell uiautomator dump /sdcard/d.xml > /dev/null 2>&1
  adb shell cat /sdcard/d.xml > $O/d.xml
  konum=$(python3 $D/dokun.py $O/d.xml "$1" $2)
  if [ -n "$konum" ]; then adb shell input tap $konum; echo "dokunuldu: $1 ($konum)"; return 0; fi
  echo "BULUNAMADI: $1"; return 1
}
kaydir() { adb shell input swipe $((G / 2)) $((Y * 75 / 100)) $((G / 2)) $((Y * 30 / 100)) 500; sleep 1; }
cek() { adb exec-out screencap -p > $O/$1.png; }

adb install -r $O/Ezan-Vakitlerim.apk > $O/kurulum.txt 2>&1
adb shell pm grant $P android.permission.POST_NOTIFICATIONS
adb logcat -c
# Açılış ekranı: "ilk kare" günlüğü düşünce, yazılar belirdikten sonra görüntü al
adb shell am start -n $P/.MainActivity
for i in $(seq 1 60); do adb logcat -d -s flutter | grep -q "Açılış ekranı: ilk kare" && break; sleep 0.3; done
acilisKareleri() { # telefonun içinde art arda 8 görüntü alır, sonra hepsini çeker
  for i in 1 2 3 4 5 6 7 8; do adb shell screencap -p /sdcard/a$i.png; echo "$1 $i $(date +%T.%N)" >> $O/kare-zaman.txt; done
  for i in 1 2 3 4 5 6 7 8; do adb pull /sdcard/a$i.png $O/$1-$i.png > /dev/null 2>&1; done
}
acilisKareleri 0-acilis
sleep 8
cek 1-acilis
dokun "Ankara"
sleep 3
cek 2-ilceler
dokun "Çankaya"
sleep 6
cek 3-vakitler
kaydir; kaydir
cek 4-vakitler-alt
if dokun "Devamını oku" || dokun "Aç ›"; then
  sleep 3
  cek 5-ayet-okuma
  adb shell input keyevent KEYCODE_BACK
  sleep 2
fi
dokun "Kıble" alt
sleep 5
cek 6-kible
dokun "Camiler" alt
sleep 25
cek 7-camiler
dokun "Ayarlar" alt
sleep 3
kaydir; kaydir
cek 8-ayarlar
kaydir; kaydir
cek 9-ayarlar2
kaydir; kaydir
cek 10-ayarlar3
# Büyük yazıyla bir tur: telefonun yazı boyutunu %140 yap, taşma var mı bak
adb shell settings put system font_scale 1.4
adb shell am force-stop $P
adb logcat -c
adb shell am start -n $P/.MainActivity
for i in $(seq 1 60); do adb logcat -d -s flutter | grep -q "Açılış ekranı: ilk kare" && break; sleep 0.3; done
acilisKareleri 0-buyuk-acilis
sleep 6
cek 11-buyuk-vakitler
kaydir; kaydir
cek 12-buyuk-vakitler-alt
dokun "İmsakiye" alt
sleep 3
cek 13-buyuk-imsakiye
adb shell settings put system font_scale 1.0
adb logcat -d > $O/logcat-tam.txt
cd $O && python3 -c "
from PIL import Image
import glob
for ad in ('0-acilis','0-buyuk-acilis'):
  d=sorted(glob.glob(ad+'-*.png'))
  if not d: continue
  ims=[Image.open(x).convert('RGB') for x in d]; w,h=ims[0].size
  o=Image.new('RGB',(w*len(ims),h))
  for i,im in enumerate(ims): o.paste(im,(i*w,0))
  o.save(ad+'-serit.png')
" || true
