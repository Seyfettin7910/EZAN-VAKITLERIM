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
adb shell am start -n $P/.MainActivity
sleep 20
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
adb logcat -d > $O/logcat-tam.txt
