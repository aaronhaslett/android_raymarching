#!/bin/bash

set -ex

usage="Usage: $0 [project_dir]";

if [ $# -ge 2 ]; then
  echo $usage;
  exit 1;
fi;

reqs="java javac keytool zip proguard";
for req in $reqs; do
  command -v $req;
done;

proj=${1:-"./"}

if [ ! -d "$proj" ]; then
  echo "dir not found: $proj";
  echo $usage;
  exit 1;
fi;

./fetch_packages.sh

tools_dir="$proj/package_dir"
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
  $tools_dir/aapt2 compile $f -o $proj/compiled;
done;
$tools_dir/aapt2 link $proj/compiled/*\
                  --java $proj/src\
                  --manifest $proj/AndroidManifest.xml\
                  -I $tools_dir/android.jar\
                  -o $proj/bin/unaligned.apk

echo "Compiling source..."
javac -d $proj/obj\
      --class-path $tools_dir/android.jar\
      -source 1.9 -target 1.9\
      `find $proj/src/ -name *.java`

echo "Proguard run on classes"
cp android.pro.template android.pro
echo "-injars $proj/obj" | tee -a android.pro;
echo "-outjars $proj/bin/classes-process.jar" | tee -a android.pro;
echo "-libraryjars ./lib" | tee -a android.pro;
cp $tools_dir/android.jar $proj/lib/;
proguard @android.pro;

echo "Dexing classes..."
$tools_dir/d8 --output $proj/bin $proj/bin/classes-process.jar

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
$tools_dir/zipalign -f 4 $proj/bin/unaligned.apk $proj/bin/hello.apk
$tools_dir/apksigner sign --ks $ks --ks-pass pass:$kspass $proj/bin/hello.apk

echo "Uploading..."
$tools_dir/adb install -r $proj/bin/hello.apk
