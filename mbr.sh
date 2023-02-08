#!/bin/bash

source utils.sh # import util functions

cd ./images/MBR

rm -rf working
mkdir -p working

cp mbr.dd working/mbr.dd

cd working

# -------------------------------------------------------------------------
echo

# Partition Table Entry 1: 0x1BE = 446 -> 16 bytes
echo "MBR: Extracting Partition Table Entry 1..."
dd if=mbr.dd of=mbr-p1.dd bs=1 skip=446 count=16 status=none

echo "-> Partition Table Entry 1"

# Partition Table Entry 1 Type: 0x04 = 4 -> 1 byte
P1TYPE=$(dd if=mbr-p1.dd bs=1 skip=4 count=1 status=none | xxd -p -u)
echo -e "\tType: $P1TYPE"

# Partition Table Entry 1: LBA of Partition Start: 0x08 = 8 -> 4 byte
P1LBA=$(dd if=mbr-p1.dd bs=1 skip=8 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tLBA of Partition Start: $P1LBA"

# Partition Table Entry 1 Size: 0x0C = 12 -> 4 bytes
P1SIZE=$(dd if=mbr-p1.dd bs=1 skip=12 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSize: $P1SIZE sectors"

# -------------------------------------------------------------------------
echo

# Partition Table Entry 2: 0x1CE = 462 -> 16 bytes
echo "MBR: Extracting Partition Table Entry 2..."
dd if=mbr.dd of=mbr-p2.dd bs=1 skip=462 count=16 status=none

echo "-> Partition Table Entry 2"

# Partition Table Entry 2 Type: 0x04 = 4 -> 1 byte
P2TYPE=$(dd if=mbr-p2.dd bs=1 skip=4 count=1 status=none | xxd -p -u)
echo -e "\tType: $P2TYPE"

# Partition Table Entry 2: LBA of Partition Start: 0x08 = 8 -> 4 byte
P2LBA=$(dd if=mbr-p2.dd bs=1 skip=8 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tLBA of Partition Start: $P2LBA"

# Partition Table Entry 2 Size: 0x0C = 12 -> 4 bytes
P2SIZE=$(dd if=mbr-p2.dd bs=1 skip=12 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSize: $P2SIZE sectors"

# -------------------------------------------------------------------------
echo

# Partition Table Entry 3: 0x1DE = 478 -> 16 bytes
echo "MBR: Extracting Partition Table Entry 3..."
dd if=mbr.dd of=mbr-p3.dd bs=1 skip=478 count=16 status=none

echo "-> Partition Table Entry 3"

# Partition Table Entry 3 Type: 0x04 = 4 -> 1 byte
P3TYPE=$(dd if=mbr-p3.dd bs=1 skip=4 count=1 status=none | xxd -p -u)
echo -e "\tType: $P3TYPE"

# Partition Table Entry 3: LBA of Partition Start: 0x08 = 8 -> 4 byte
P3LBA=$(dd if=mbr-p3.dd bs=1 skip=8 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tLBA of Partition Start: $P3LBA"

# Partition Table Entry 3 Size: 0x0C = 12 -> 4 bytes
P3SIZE=$(dd if=mbr-p3.dd bs=1 skip=12 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSize: $P3SIZE sectors"

# -------------------------------------------------------------------------
echo

# Partition Table Entry 4: 0x1FE = 494 -> 16 bytes
echo "MBR: Extracting Partition Table Entry 4..."
dd if=mbr.dd of=mbr-p4.dd bs=1 skip=494 count=16 status=none

echo "-> Partition Table Entry 4"

# Partition Table Entry 4 Type: 0x04 = 4 -> 1 byte
P4TYPE=$(dd if=mbr-p4.dd bs=1 skip=4 count=1 status=none | xxd -p -u)
echo -e "\tType: $P4TYPE"

# Partition Table Entry 4: LBA of Partition Start: 0x08 = 8 -> 4 byte
P4LBA=$(dd if=mbr-p4.dd bs=1 skip=8 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tLBA of Partition Start: $P4LBA"

# Partition Table Entry 4 Size: 0x0C = 12 -> 4 bytes
P4SIZE=$(dd if=mbr-p4.dd bs=1 skip=12 count=4 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSize: $P4SIZE sectors"

# -------------------------------------------------------------------------

# Assuming sectors are 512 bytes (legacy)
# https://www.reddit.com/r/computerforensics/comments/9tbz53/does_master_boot_record_contain_the_sector_size/

# echo "Extracting Partition 1..." # P1LBA -> (P1LBA + P1SIZE) sectors
# dd if=mbr.dd of=p1.dd bs=512 skip=$P1LBA count=$P1SIZE status=none
# md5sum p1.dd

# echo "Extracting Partition 2..." # P2LBA -> (P2LBA + P2SIZE) sectors
# dd if=mbr.dd of=p2.dd bs=512 skip=$P2LBA count=$P2SIZE status=none
# md5sum p2.dd

# echo "Extracting Partition 3..." # P3LBA -> (P3LBA + P3SIZE) sectors
# dd if=mbr.dd of=p3.dd bs=512 skip=$P3LBA count=$P3SIZE status=none
# md5sum p3.dd

# echo "Extracting Partition 4..." # P4LBA -> (P4LBA + P4SIZE) sectors
# dd if=mbr.dd of=p4.dd bs=512 skip=$P4LBA count=$P4SIZE status=none
# md5sum p4.dd

# http://www.osdever.net/documents/partitiontypes.php
