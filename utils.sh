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
    echo "ibase=16;$TMPVAL" | bc
}

# Hexa to binary
function hex2bin() {
    read TMPVAL
    echo "ibase=16;obase=2;$TMPVAL" | bc
}

# Bin to decimal
function bin2deci() {
    read TMPVAL
    echo "ibase=2;$TMPVAL" | bc
}

# Pad binary with 0's in multiples of bytes
# e.g. 1001 > 00001001
# e.g. 010011001 > 00000000 10011001
function padbin() {
    read TMPVAL
    CHARCOUNT="${#TMPVAL}"
    let "QUOTIENT = $CHARCOUNT / 8"
    let "REMAINDER = $CHARCOUNT % 8"
    if [ "$REMAINDER" != "0" ]; then
        let "QUOTIENT = $QUOTIENT + 1"
    fi
    let "PADBITS = QUOTIENT * 8"
    printf "%0${PADBITS}d" $TMPVAL
}
