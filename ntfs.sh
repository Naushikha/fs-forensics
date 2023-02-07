#!/bin/bash

cd ./images/ntfs

rm -rf working
mkdir -p working

cp simple.ntfs working/ntfs.dd

cd working

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

echo "Number of bytes per sector"
dd if=ntfs.dd bs=1 skip=11 count=2 status=none | xxd -p | le2be | hex2deci

echo "Number of sectors per cluster"
dd if=ntfs.dd bs=1 skip=13 count=1 status=none | xxd -p | le2be | hex2deci

# The cluster address of the MFT is stored in bytes 48–55.
echo "cluster address of the MFT"
dd if=ntfs.dd bs=1 skip=48 count=8 status=none | xxd -p | le2be | hex2deci

# echo "From NTFS: extracting boot sector"
# dd if=ntfs.dd of=boot-sector.dd bs=1 count=512 status=none

# echo "From boot sector: name"
# dd if=boot-sector.dd bs=1 skip=3 count=8 status=none
# echo

# echo "From boot sector: size of a sector"
# SECTORSIZE=$(dd if=boot-sector.dd bs=1 skip=11 count=2 status=none | xxd -p | le2be | hex2deci)
# echo $SECTORSIZE

# echo "From boot sector: number of sectors in each cluster"
# dd if=boot-sector.dd bs=1 skip=13 count=1 status=none | xxd -p | le2be | hex2deci

# echo "From boot sector: number of reserved sectors"
# RESERVEDSECTORS=$(dd if=boot-sector.dd bs=1 skip=14 count=2 status=none | xxd -p | le2be | hex2deci)
# echo $RESERVEDSECTORS

# echo "From boot sector: number of FAT tables"
# FATNUM=$(dd if=boot-sector.dd bs=1 skip=16 count=1 status=none | xxd -p | le2be | hex2deci)
# echo $FATNUM

# echo "From boot sector: number of entries in the root directory"
# ROOTDIRENTRIES=$(dd if=boot-sector.dd bs=1 skip=17 count=2 status=none | xxd -p | le2be | hex2deci)
# echo $ROOTDIRENTRIES

# echo "From boot sector: number of sectors per FAT"
# FATSECTORS=$(dd if=boot-sector.dd bs=1 skip=22 count=2 status=none | xxd -p | le2be | hex2deci)
# echo $FATSECTORS

# echo "From FAT16: extracting FAT table 1"
# dd if=fat16.dd of=fat-table.dd bs=$SECTORSIZE skip=$RESERVEDSECTORS count=$FATSECTORS status=none

# # Offset to root directory = (reserved space) + (FAT table size)×(number of FAT tables)
# echo "Offset to root directory"
# let "ROOTDIROFFSET = $RESERVEDSECTORS + $FATSECTORS * $FATNUM"
# echo "$ROOTDIROFFSET sectors"

# # Size of root directory = number of root directory entries x size of directory entry (32 bytes)
# echo "Size of root directory"
# let "ROOTDIRSIZE = $ROOTDIRENTRIES * 32"
# echo "$ROOTDIRSIZE bytes"

# echo "From FAT16: extracting root directory"
# let "SKIPBYTES = $ROOTDIROFFSET * $SECTORSIZE"
# dd if=fat16.dd of=root-dir.dd bs=1 skip=$SKIPBYTES count=$ROOTDIRSIZE status=none

# https://www.win.tue.nl/~aeb/linux/fs/fat/fat-1.html
