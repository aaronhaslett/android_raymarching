#!/bin/bash

set -e

usage="Usage: $0 project_dir android_tools_dir";

if [ $# -ne 2 ]; then
  echo $usage;
  exit 1;
fi;

for dir in "$@"; do
  if [ ! -d "$dir" ]; then
    echo "dir not found: $dir";
    echo $usage;
    exit 1;
  fi;
done;

command -v java -v javac -v keytool -v zip;

proj="$1";
base_path="$2";

ks="$proj/keystore.jks";
kspass="android";

echo "Cleaning..."
rm -rf $proj/src/com/example/helloandroid/R.java
rm -f $ks

for dir in lib obj bin compiled; do
  rm -rf "$proj/$dir";
  mkdir "$proj/$dir";
done;

echo "Compiling and linking resources into APK..."
for f in `find $proj/res -type f`; do
  $proj/ext/aapt2 compile $f -o $proj/compiled;
done;
$proj/ext/aapt2 link $proj/compiled/*\
                  --java $proj/src\
                  --manifest $proj/AndroidManifest.xml\
                  -I $proj/ext/android.jar\
                  -o $proj/bin/unaligned.apk

echo "Compiling source..."
javac -d $proj/obj\
      --class-path $proj/ext/android.jar\
      -source 1.9 -target 1.9\
      `find $proj/src/ -name *.java`

if command -v proguard; then
  echo "Proguard run on classes"
  cp android.pro.template android.pro
  echo "-injars $proj/obj" | tee -a android.pro;
  echo "-outjars $proj/bin/classes-process.jar" | tee -a android.pro;
  echo "-libraryjars ./lib" | tee -a android.pro;
  cp $proj/ext/android.jar $proj/lib/;
  proguard @android.pro;
fi;

echo "Dexing classes..."
$proj/ext/d8 --output $proj/bin $proj/bin/classes-process.jar

echo "Adding dex file to APK..."
zip -uj $proj/bin/unaligned.apk $proj/bin/classes.dex

if [ ! -f $ks ]; then
  echo "Keygen..."
  keytool -genkeypair\
          -keystore $ks\
          -alias androidkey \
          -validity 10000\
          -keyalg RSA\
          -keysize 2048 \
          -storepass $kspass\
          -keypass $kspass\
          -dname "CN=Unknown,OU=Unknown,O=Unknown,L=Unknown,ST=Unknown,C=Unknown";
fi;

echo "Aligning and signing APK..."
$proj/ext/zipalign -f 4 $proj/bin/unaligned.apk $proj/bin/hello.apk
$proj/ext/apksigner sign --ks $ks --ks-pass pass:$kspass $proj/bin/hello.apk

echo "Uploading..."
$proj/ext/adb install -r $proj/bin/hello.apk
