#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 8 ]; then
  echo "Usage: validate-kpm-recipe.sh <use_kpm> <android_version> <kernel_version> <sub_level> <add_nomount> <add_zeromount> <version> <build_time>" >&2
  exit 2
fi

use_kpm=$1
android_version=$2
kernel_version=$3
sub_level=$4
add_nomount=$5
add_zeromount=$6
version=$7
build_time=$8

[ "$use_kpm" = true ] || exit 0

if [ "$android_version" != android12 ] ||
   [ "$kernel_version" != 5.10 ] ||
   [ "$sub_level" != 236 ]; then
  echo "KPM is supported only for android12-5.10.236" >&2
  exit 1
fi

if [ "$add_nomount" != true ]; then
  echo "KPM recipe requires add_nomount=true" >&2
  exit 1
fi

if [ "$add_zeromount" != false ]; then
  echo "KPM recipe requires add_zeromount=false" >&2
  exit 1
fi

expected_version='5.10.236-android12-9-00085-g226a9632f13d-ab11136126'
expected_build_time='Wed Nov 22 14:16:37 UTC 2023'
if [ "$version" != "$expected_version" ]; then
  echo "KPM recipe requires version=$expected_version" >&2
  exit 1
fi
if [ "$build_time" != "$expected_build_time" ]; then
  echo "KPM recipe requires build_time=$expected_build_time" >&2
  exit 1
fi
