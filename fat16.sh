#!/bin/bash

source utils.sh # import util functions
source utils.fat16.sh # import FAT16 utility functions

cd ./images/FAT16

rm -rf working
mkdir -p working

cp asanka.dd working/fat16.dd

cd working

# -------------------------------------------------------------------
echo

echo "FAT16: Extracting Boot Sector..." # 512 Bytes
dd if=fat16.dd of=boot-sector.dd bs=1 count=512 status=none

echo "-> Boot Sector"

# OEM Name: 0x03 = 3 -> 8 bytes
OEMNAME=$(dd if=boot-sector.dd bs=1 skip=3 count=8 status=none)
echo -e "\tOEM Name: $OEMNAME" 

# Check if FAT12/16: Page 255 in ref. book
# File System Type Label: 0x36 = 54 -> 8 bytes
FSLABEL=$(dd if=boot-sector.dd bs=1 skip=54 count=8 status=none)
echo -e "\tFile System Type Label: $FSLABEL"

# Bytes Per Sector: 0x0B = 11 -> 2 bytes
SECTORSIZE=$(dd if=boot-sector.dd bs=1 skip=11 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tBytes Per Sector: $SECTORSIZE bytes"

# Sectors Per Cluster: 0x0D = 13 -> 1 byte
CLUSTERSECTORS=$(dd if=boot-sector.dd bs=1 skip=13 count=1 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSectors Per Cluster: $CLUSTERSECTORS" 

# Size in Sectors of the Reserved Area: 0x0E = 14 -> 2 bytes
RESERVEDSECTORS=$(dd if=boot-sector.dd bs=1 skip=14 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSize in Sectors of the Reserved Area: $RESERVEDSECTORS" 

# Number of FATs: 0x10 = 16 -> 1 byte
FATNUM=$(dd if=boot-sector.dd bs=1 skip=16 count=1 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tNumber of FATs: $FATNUM" 

# Maximum Number of Files in the Root Directory:  0x11 = 17 -> 2 bytes
ROOTDIRENTRIES=$(dd if=boot-sector.dd bs=1 skip=17 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tMaximum Number of Files in the Root Directory: $ROOTDIRENTRIES" 

# Size in Sectors of Each FAT: 0x16 = 22 -> 2 bytes
FATSECTORS=$(dd if=boot-sector.dd bs=1 skip=22 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSize in Sectors of Each FAT: $FATSECTORS"

# -------------------------------------------------------------------
echo

# Sector Offset to root directory = (reserved space) + (FAT table size)×(number of FAT tables)
let "ROOTDIROFFSET = $RESERVEDSECTORS + $FATSECTORS * $FATNUM"
echo "[Calc] Sector Offset to Root Directory: $ROOTDIROFFSET sectors"

# Size of root directory = number of root directory entries x size of directory entry (32 bytes)
let "ROOTDIRSIZE = $ROOTDIRENTRIES * 32 / $SECTORSIZE"
echo "[Calc] Size of Root Directory: $ROOTDIRSIZE sectors"

# Sector offset to data area = root directory offset + root directory size
let "DATAOFFSET = $ROOTDIROFFSET + $ROOTDIRSIZE"
echo "[Calc] Sector Offset to Data Area: $DATAOFFSET sectors"

# Size of cluster = sectors in cluster * sector size
let "CLUSTERSIZE = $CLUSTERSECTORS * $SECTORSIZE"
echo "[Calc] Size of Cluster: $CLUSTERSIZE bytes"

# -------------------------------------------------------------------
echo

echo "FAT16: Extracting FAT Table..." # Usually 2 FATs for redundancy
let "FATOFFSET = $RESERVEDSECTORS + $FATSECTORS * 0" # 0 for FAT-1, 1 for FAT-2
dd if=fat16.dd of=fat-table.dd bs=$SECTORSIZE skip=$FATOFFSET count=$FATSECTORS status=none

echo "FAT16: Extracting Root Directory..."
dd if=fat16.dd of=root-dir.dd bs=$SECTORSIZE skip=$ROOTDIROFFSET count=$ROOTDIRSIZE status=none

echo "FAT16: Extracting Data Area..."
dd if=fat16.dd of=data-area.dd bs=$SECTORSIZE skip=$DATAOFFSET status=none

# -------------------------------------------------------------------
echo

list_dir_entries "root-dir.dd" "$ROOTDIRENTRIES"

# For asanka.dd
# extract_file "test.txt" "3" "104"
# extract_file "folder" "4" "0" # Extracting a directory
# list_dir_entries "folder.dd" "0"
# extract_file "ASCII_code_chart.png" "5" "37769"
# extract_file "deleted.txt" "0" "0"

# For adams.dd
extract_file "images" "3" "0" # Directory
list_dir_entries "images.dd" "0"
extract_file "Designs.doc" "1837" "2585088"
extract_deleted_file "IMG_3027.jpg" "4" "1876108"

# Find out hidden clusters
# list_cluster_chains

# ** Only Files, Directories, and LFNs are considered
# https://www.win.tue.nl/~aeb/linux/fs/fat/fat-1.html
# https://people.cs.umass.edu/~liberato/courses/2018-spring-compsci365+590f/lecture-notes/11-fats-and-directory-entries/
# https://people.cs.umass.edu/~liberato/courses/2018-spring-compsci365+590f/lecture-notes/12-demonstration-parsing-fat/
