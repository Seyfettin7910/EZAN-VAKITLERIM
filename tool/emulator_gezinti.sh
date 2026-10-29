#!/bin/bash
# Emülatörde uygulamayı açar, konum seçer, sekmeleri gezer ve her ekranın görüntüsünü alır.
# GitHub Actions'taki "APK kontrol" işi (gezinti seçeneğiyle) çalıştırır.
O=/tmp/k
P=com.seyfettin.ezan_vakitlerim
D=$(dirname "$0")

dokun() { # yazısı $1 olan öğeye dokunur ($2 = "alt" ise en alttakine)
  adb shell uiautomator dump /sdcard/d.xml > /dev/null 2>&1
  adb shell cat /sdcard/d.xml > $O/d.xml
  konum=$(python3 $D/dokun.py $O/d.xml "$1" $2)
  if [ -n "$konum" ]; then adb shell input tap $konum; echo "dokunuldu: $1 ($konum)"; else echo "BULUNAMADI: $1"; fi
}
cek() { adb exec-out screencap -p > $O/$1.png; }

adb install -r $O/Ezan-Vakitlerim.apk > $O/kurulum.txt 2>&1
adb shell pm grant $P android.permission.POST_NOTIFICATIONS
adb shell pm grant $P android.permission.ACCESS_FINE_LOCATION
adb logcat -c
adb shell am start -n $P/.MainActivity
sleep 20
cek 1-acilis
dokun "Ankara"
sleep 6
cek 2-vakitler
adb shell input swipe 500 1600 500 500 600
sleep 2
cek 3-vakitler-alt
dokun "Devamını oku"
sleep 3
cek 4-ayet-okuma
adb shell input keyevent KEYCODE_BACK
sleep 2
dokun "Kıble" alt
sleep 5
cek 5-kible
dokun "Camiler" alt
sleep 25
cek 6-camiler
dokun "Ayarlar" alt
sleep 3
adb shell input swipe 500 1700 500 300 600
sleep 1
adb shell input swipe 500 1700 500 300 600
sleep 2
cek 7-ayarlar
adb shell input swipe 500 1700 500 300 600
sleep 2
cek 8-ayarlar2
adb logcat -d > $O/logcat-tam.txt
