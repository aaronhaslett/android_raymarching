#!/bin/bash

set -ex

packages="build-tools;30.0.3 platforms;android-30";
tools_to_link="aapt aapt2 d8 zipalign apksigner adb android.jar";

usage="Usage: $0 [proj_dir]";

if [ $# -ge 2 ]; then
  echo $usage;
  exit 1;
fi;

proj=${1:-"./"}
package_dir="$proj/package_dir"
if [ ! -d $package_dir ]; then mkdir $package_dir; fi;

tools_zip="commandlinetools-linux-6858069_latest.zip";
sdkmanager_path="$package_dir/cmdline-tools/bin/sdkmanager";

if [ ! -f "$sdkmanager_path" ]; then
  if [ ! -f "$tools_zip" ]; then
    curl https://dl.google.com/android/repository/$tools_zip -o $tools_zip;
  fi;
  unzip $tools_zip -d $package_dir
fi;

for package in $packages; do
  package_path="$package_dir/`echo $package | sed s/\;/-/g`"
  if [ -d $package_path ]; then continue; fi;
  yes | $sdkmanager_path --sdk_root=$package_path --channel=0 --install "$package";
done;

for tool in $tools_to_link; do
  if [ -L $package_dir/$tool ]; then
    continue;
  fi;

  # Don't try to collapse the two checks in this loop.
  # "echo | wc" can't distinguish between empty string and one result.
  # No, adding -n to echo doesn't work.

  path=`find $package_dir -type f -name $tool`;
  if [ -z $path ]; then
    echo "$tool not found in path $package_dir";
    exit 1;
  fi

  num=`echo $path | wc -l`;
  if [ $num -ne 1 ]; then
    echo "Expected to find 1 $tool but found $num: $path"
    exit 1;
  fi

  ln -s `realpath $path` $package_dir/$tool
done;
