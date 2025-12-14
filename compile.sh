#!/bin/bash
if [ $# -eq 0 ]; then
    FILE="limbaj"
else
    FILE="$1"
fi
rm -f lex.yy.c parser.tab.c parser.tab.h limbaj
bison -d parser.y
flex scanner.l
g++ lex.yy.c parser.tab.c -o "$FILE"
./"$FILE" < input.txt