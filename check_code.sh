#!/bin/bash

cd "$(dirname "$BASH_SOURCE[0]")"

function quality_check() {

  egrep -n '[[:blank:]]+$' "$1" &&
    echo '>>> TRAILING SPACES <<<'

  egrep -l '@private\b' "$1" &&
    echo '>>> @private INSTEAD OF @api private <<<'

  egrep -l '^=begin\s*$' "$1" &&
    echo '>>> =begin WITHOUT QUALIFIER <<<'

  egrep -l '^@param\s+\[' "$1" &&
    echo '>>> @param [Type] name INSTEAD OF @param name [Type] <<<'

}

for i in `find lib -name \*.rb`; do
  echo -n "${i}..."
  ruby -w -I lib "$i" && echo " OK"
  quality_check "$i"
done
