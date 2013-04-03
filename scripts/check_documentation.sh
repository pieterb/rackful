#!/bin/bash

cd "$(dirname "$BASH_SCRIPT[0]")"/../lib
grep -rlP '[ \t]+$' . &&
	echo '>>> TRAILING SPACES <<<'
grep -rlP '@private\b' . &&
	echo '>>> @private INSTEAD OF @api private <<<'
grep -rlP '^=begin\s*$' . &&
	echo '>>> =begin WITHOUT QUALIFIER <<<'
grep -rlP '^@param\s+\[' . &&
	echo '>>> @param [Type] name INSTEAD OF @param name [Type] <<<'
