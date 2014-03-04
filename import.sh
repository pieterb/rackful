#!/bin/bash
# This script is supposed to be run before each git commit.

# Establish the top level repository directory:
REPODIR=$( dirname "${BASH_SOURCE[0]}" )

# Echo everything we do to export.log:
set -x
{

### Step 1: General ###
cd "${REPODIR}"

} 2>"export.log"
