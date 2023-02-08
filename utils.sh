#!/bin/bash

# Common Utility Functions

# Convert between endian-ness
# https://stackoverflow.com/a/39564881
# echo 0002 | tac -rs .. | echo "$(tr -d '\n')"
function le2be() {
    read TMPVAL
    echo $TMPVAL | tac -rs .. | echo "$(tr -d '\n')"
}

# Hexa to decimal
function hex2deci() {
    read TMPVAL
    echo "ibase=16;$TMPVAL" | bc -l
}
