#!/bin/bash

cd "$(dirname "$BASH_SCRIPT[0]")"/lib

function quality_check() {

  grep -rlP '[ \t]+$' "$0" &&
    echo '>>> TRAILING SPACES <<<'

  grep -rlP '@private\b' "$0" &&
    echo '>>> @private INSTEAD OF @api private <<<'

  grep -rlP '^=begin\s*$' "$0" &&
    echo '>>> =begin WITHOUT QUALIFIER <<<'

  grep -rlP '^@param\s+\[' "$0" &&
    echo '>>> @param [Type] name INSTEAD OF @param name [Type] <<<'

}

for i in `find . -name \*.rb`; do
  echo -n "${i}..."
  ruby "$i" && echo " OK"
  quality_check "$i"
done
