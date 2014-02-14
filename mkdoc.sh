#!/bin/bash
# Nice options: server --reload

cd "`dirname "${BASH_SOURCE[0]}"`"

rm -rf doc/* .yardoc/
yard --yardopts .yardopts.user
yard --yardopts .yardopts.devel
