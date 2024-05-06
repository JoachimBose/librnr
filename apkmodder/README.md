# Android Apk modding
## The plan
LD_PRELOAD is really hard on android and requires root, so we have to adapt and
do something like this:
1. unpack APK
2. place shared library in the APK
3. update the manifest of APK to include our shared lib
4. repack the APK
5. install it on the device
6. pray to android that they link to librnr and that it works

## The execution so far
So far, this is what has been done:
 * The APK has been unpacked and modified by Jesse Donkervliet
 * The APK has been correctly repacked and resigned and installs on a phone using
some opencraft-2 headset build apk
 * The APK has not yet been tested or installed on MQ3
