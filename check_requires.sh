#!/bin/bash

cd "`dirname "$0"`"
#if ! [ -f epic.rb ]; then
#  echo "Run this script from the top level directory." >&2
#  exit 1
#fi
for i in lib/rackful_*.rb; do
  echo -n "${i}..."
  ruby -I lib $i && echo " OK"
done
