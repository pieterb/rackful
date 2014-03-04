#!/bin/bash
# This script is supposed to be run after each git checkout or update.

# Establish the top level repository directory:
cd "$( dirname "${BASH_SOURCE[0]}" )"
REPODIR="$PWD"

# Echo everything we do to export.log:
set -x
{

### Step 1: General ###

# Some files (.rvmrc and .project for example) may differ per developer.
# In the git repo, these files are called <file_name>.<developer_name>.
# For example: ".rvmrc.pieterb"
# The following lines put such files in place:
find . -name "*.${USER}" | while read i; do
    if ! [ -e "${i%\.${USER}}" ]; then
        echo -n "Creating symlink for '${i}'..."
        ln -s "`basename "${i}"`" "${i%\.${USER}}" && echo ' OK' || echo ' FAILED'
    fi
done

[ -h rack ] && rm rack
[ -e rack ] || ln -s "${GEM_HOME}/gems/rack-"[0-9]* rack

} 2>"export.log"
