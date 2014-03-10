#!/bin/bash
# This script is supposed to be run after each git checkout or update.

# Establish the top level repository directory:
cd "$( dirname "${BASH_SOURCE[0]}" )"
REPODIR="$PWD"

GIT_REPOSITORIES="$(
  find . -name .git -mindepth 2 | while read i; do
    echo -n " -not -path '$(dirname "$i")/*'"
  done
)"

# Link to user-specific files:
find . -name "*.${USER}" $GIT_REPOSITORIES -not -path './client/data/*' |
while read i; do
  if ! [ -e "${i%\.${USER}}" ]; then
    echo -n "Creating symlink for '${i}'..."
    ln -s "`basename "${i}"`" "${i%\.${USER}}" && echo ' OK' || echo ' FAILED'
  else
    [ -h "${i%\.${USER}}" ] || echo "WARNING: ${i%\.${USER}} is not a symlink!"
  fi
done

# Run export.sh scripts in subdirectories:
eval "find . -name 'export.sh' -mindepth 2 $GIT_REPOSITORIES" |
while read i; do
  pushd "$(dirname "$i")" &>/dev/null
    echo "Running ${i}..."
    ./export.sh
    echo "... Done"
  popd &>/dev/null
done

[ -h rack ] && rm rack
[ -e rack ] || ln -s "${GEM_HOME}/gems/rack-"[0-9]* rack
