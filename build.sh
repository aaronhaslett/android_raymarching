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

command -v java -v javac -v keytool -v zip -v proguard;

proj="$1";
base_path="$2";
tools="aapt aapt2 d8 zipalign apksigner adb android.jar"

declare -A paths

for tool in $tools; do

  # Don't try to collapse the two checks in this loop.
  # "echo | wc" can't distinguish between empty string and one result.
  # No, adding -n to echo doesn't work.

  res=`find $base_path -type f -name $tool`;
  if [ -z $res ]; then
    echo "$tool not found in path $base_path";
    exit 1;
  fi

  num=`echo $res | wc -l`;
  if [ $num -ne 1 ]; then
    echo "Expected to find 1 $tool but found $num: $res"
    exit 1;
  fi

  paths["$tool"]="$res";
done;

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
  ${paths["aapt2"]} compile $f -o $proj/compiled;
done;
${paths["aapt2"]} link $proj/compiled/*\
                  --java $proj/src\
                  --manifest $proj/AndroidManifest.xml\
                  -I ${paths["android.jar"]}\
                  -o $proj/bin/unaligned.apk

echo "Compiling source..."
javac -d $proj/obj\
      --class-path ${paths["android.jar"]}\
      -source 1.9 -target 1.9\
      `find $proj/src/ -name *.java`

echo "Proguard run on classes"
cp android.pro.template android.pro
echo "-injars $proj/obj" | tee -a android.pro;
echo "-outjars $proj/bin/classes-process.jar" | tee -a android.pro;
echo "-libraryjars ./lib" | tee -a android.pro;
cp ${paths["android.jar"]} $proj/lib/
proguard @android.pro

echo "Dexing classes..."
${paths["d8"]} --output $proj/bin $proj/bin/classes-process.jar

echo "Adding dex file to APK..."
zip -uj $proj/bin/unaligned.apk $proj/bin/classes.dex

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

echo "Aligning and signing APK..."
${paths["zipalign"]} -f 4 $proj/bin/unaligned.apk $proj/bin/hello.apk
${paths["apksigner"]} sign --ks $ks --ks-pass pass:$kspass $proj/bin/hello.apk

echo "Uploading..."
${paths["adb"]} install -r $proj/bin/hello.apk
