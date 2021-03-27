#!/bin/bash

# 1. Fetching android build requirements using sdkmanager
# 2. Make symbolic links for the stuff we actually need
# This is intended to be run on every build, so it doesn't
# do anything unnecessary.
# It's not possible to just pull the needed binaries out because it's
# java and there's a dependency structure inside the package.

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

# Fetch sdkmanager if we don't already have it.
if [ ! -f "$sdkmanager_path" ]; then
  if [ ! -f "$tools_zip" ]; then
    curl https://dl.google.com/android/repository/$tools_zip -o $tools_zip;
  fi;
  unzip $tools_zip -d $package_dir
fi;

# Fetch packages if we don't have them
for package in $packages; do
  # Take the package name and remove the semicolon, then use the result as a path
  package_path="$package_dir/`echo $package | sed s/\;/-/g`"
  if [ -d $package_path ]; then continue; fi;
  yes | $sdkmanager_path --sdk_root=$package_path --channel=0 --install "$package";
done;

# Look for each tool and check we can only find one in the dir of packages
# we just pulled.  If there's only one, then that's what we're looking for,
# make a link for the build script to use.
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
