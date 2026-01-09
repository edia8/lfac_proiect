#!/bin/bash
# if [ $# -eq 0 ]; then
#     FILE="limbaj"
# else
#     FILE="$1"
# fi
# rm -f lex.yy.cpp parser.tab.cpp parser.tab.hpp limbaj
# bison -d parser.y
# flex scanner.l
# g++ lex.yy.cpp parser.tab.cpp -o "$FILE" -std=c++17
# ./"$FILE" < input.txt

echo "1. Cleaning..."
rm -f lex.yy.cpp parser.tab.cpp parser.tab.hpp limbaj

echo "2. Running Bison..."
bison -d -o parser.tab.cpp parser.y || { echo "BISON FAILED"; exit 1; }

echo "3. Running Flex..."
flex -o lex.yy.cpp scanner.l || { echo "FLEX FAILED"; exit 1; }

echo "4. Compiling..."
g++ -g lex.yy.cpp parser.tab.cpp -o limbaj -std=c++17 || { echo "G++ FAILED"; exit 1; }

echo "5. Running..."
./limbaj < complex_sample.txt
