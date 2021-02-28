#!/bin/bash

# Written with the input file commandlinetools-linux-6858069_latest.zip as
# test but hoping it generalises.

usage="Usage: $0 /path/to/cmdlinetools.zip /path/to/project"
if [ $# -ne 2 ]; then
  echo $usage;
  exit 1;
fi;

tools_zip=$1;
if [ ! -f $1 ]; then
  echo "file not found: $tools_zip";
  echo $usage;
  exit 1;
fi;

proj=$2;
if [ ! -d $proj ]; then
  echo "dir not found: $proj";
  echo $usage;
  exit 1;
fi;

mkdir $proj/cmdlinetools;
cd $proj/cmdlinetools;
unzip $tools_zip;
cd cmdline-tools;
./bin/sdkmanager --install --channel=1 "platforms;android-28" --sdk_root=./
./bin/sdkmanager --install --channel=1 "build-tools;28.0.3" --sdk_root=./

tools="aapt aapt2 d8 zipalign apksigner adb android.jar"

paths="";
for tool in $tools; do

  # Don't try to collapse the two checks in this loop.
  # "echo | wc" can't distinguish between empty string and one result.
  # No, adding -n to echo doesn't work.

  res=`find . -type f -name $tool`;
  if [ -z $res ]; then
    echo "$tool not found";
    exit 1;
  fi

  num=`echo $res | wc -l`;
  if [ $num -ne 1 ]; then
    echo "Expected to find 1 $tool but found $num: $res"
    exit 1;
  fi

  paths="$paths $res";
done;

mkdir $proj/ext;

for path in $paths; do
  mv $path $proj/ext/
done;

rm -rf $proj/cmdlinetools;
