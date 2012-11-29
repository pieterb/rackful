#!/bin/bash

cd "`dirname "$0"`"

rm -rf doc/* .yardoc/
exec yard "$@"
