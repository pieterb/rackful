#!/bin/bash

cd "`dirname "$0"`"

rm -rf docs/* .yardoc/
exec yard "$@"
