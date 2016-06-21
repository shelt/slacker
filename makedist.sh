#!/bin/bash
declare -x DEL='###################'
mkdir -p dist/

cat include.sh > dist/slacker.sh

find functions/ -name '*.sh' -exec sh -c 'echo -e "\n\n$DEL {} $DEL"; cat {}'  \; >> dist/slacker.sh

echo -e "\n\n$DEL MAIN $DEL" >> dist/slacker.sh
cat main.sh >> dist/slacker.sh