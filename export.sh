#!/bin/bash
# This script is supposed to be run after each git checkout or update.

# Establish the top level repository directory:
cd "$( dirname "${BASH_SOURCE[0]}" )"
REPODIR="$PWD"

function export_recursively() {
  [ -n "$1" ] && pushd "$1" &>/dev/null
  [ -d '.git' ] && [ -n "$1" ] || {
    # This code is run only for non-subrepositories:
    find . -type d -maxdepth 1 -mindepth 1 | while read i; do
      [ './.git' = "$i" ] || export_recursively "$i"
    done
    find . -name "*.${USER}" -maxdepth 1 | while read i; do
      if ! [ -e "${i%\.${USER}}" ]; then
        echo -n "Creating symlink for '${i}'..."
        ln -s "`basename "${i}"`" "${i%\.${USER}}" && echo ' OK' || echo ' FAILED'
      fi
    done
  }
  [ -n "$1" ] && {
    [ -x 'export.sh' ] && './export.sh'
    popd &>/dev/null
  }
}

# Echo everything we do to export.log:
set -x
{
  export_recursively
  [ -h rack ] && rm rack
  [ -e rack ] || ln -s "${GEM_HOME}/gems/rack-"[0-9]* rack
} 2>'export.log'
