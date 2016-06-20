#!/bin/bash
declare -x DEL='###################'

cat include.sh > dist/slacker.sh

mkdir -p dist/
find functions/ -name '*.sh' -exec sh -c 'echo "\$DEL {} $DEL"; cat {}'  \; >> dist/slacker.sh

echo "$DEL MAIN $DEL" >> dist/slacker.sh
cat main.sh >> dist/slacker.sh