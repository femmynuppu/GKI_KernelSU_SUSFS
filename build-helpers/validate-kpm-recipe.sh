#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 6 ]; then
  echo "Usage: validate-kpm-recipe.sh <use_kpm> <android_version> <kernel_version> <sub_level> <add_nomount> <add_zeromount>" >&2
  exit 2
fi

use_kpm=$1
android_version=$2
kernel_version=$3
sub_level=$4
add_nomount=$5
add_zeromount=$6

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
