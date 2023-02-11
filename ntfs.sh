#!/bin/bash

source utils.sh      # import util functions
source utils.ntfs.sh # import NTFS utility functions

cd ./images/NTFS

rm -rf working
mkdir -p working

cp asanka.dd working/ntfs.dd

cd working

# -------------------------------------------------------------------
echo

echo "NTFS: Extracting Boot Sector..." # 512 Bytes
dd if=ntfs.dd of=boot-sector.dd bs=1 count=512 status=none

echo "-> Boot Sector"

# OEM Name: 0x03 = 3 -> 8 bytes
OEMNAME=$(dd if=boot-sector.dd bs=1 skip=3 count=8 status=none)
echo -e "\tOEM Name: $OEMNAME"

# Bytes Per Sector: 0x0B = 11 -> 2 bytes
SECTORSIZE=$(dd if=boot-sector.dd bs=1 skip=11 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tBytes Per Sector: $SECTORSIZE bytes"

# Sectors Per Cluster: 0x0D = 13 -> 1 byte
CLUSTERSECTORS=$(dd if=boot-sector.dd bs=1 skip=13 count=1 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tSectors Per Cluster: $CLUSTERSECTORS"

# Starting Cluster for MFT: 0x38 = 48 -> 8 bytes
MFTCLUSTER=$(dd if=ntfs.dd bs=1 skip=48 count=8 status=none | xxd -p -u | le2be | hex2deci)
echo -e "\tStarting Cluster for MFT: $MFTCLUSTER"

# Offset to MFT = Cluster Size (Bytes) x Starting Cluster for MFT
let "MFTOFFSET = $CLUSTERSECTORS * $SECTORSIZE * $MFTCLUSTER"
echo "[Calc] Offset to MFT: $MFTOFFSET bytes"

# -------------------------------------------------------------------
echo

# Brute force all MFT entries
# for i in {10..75}; do
#     list_mft_entry "$i"
# done

list_mft_entry "64"
list_mft_entry "65"

# Manual listing,
# extract_mft_entry "65"
# extract_mft_entry_attribute "352"

# Extract non-resident file
extract_file "8707" "3" "9583" "pat.gif"
