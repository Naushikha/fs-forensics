#!/bin/bash

cd ./images/FAT16

rm -rf working
mkdir -p working

cp asanka.dd working/fat16.dd

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

echo "FAT16: Extracting Boot Sector" # 512 Bytes
dd if=fat16.dd of=boot-sector.dd bs=1 count=512 status=none

echo "Boot Sector: OEM Name" # 0x03 = 3 -> 8 bytes
dd if=boot-sector.dd bs=1 skip=3 count=8 status=none
echo

# Check if FAT12/16: Page 255 in ref. book
echo "Boot Sector: File System Type Label" # 0x36 = 54 -> 8 bytes
dd if=boot-sector.dd bs=1 skip=54 count=8 status=none
echo

echo "Boot Sector: Bytes Per Sector" # 0x0B = 11 -> 2 bytes
SECTORSIZE=$(dd if=boot-sector.dd bs=1 skip=11 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo $SECTORSIZE

echo "Boot Sector: Sectors Per Cluster" # 0x0D = 13 -> 1 byte
CLUSTERSECTORS=$(dd if=boot-sector.dd bs=1 skip=13 count=1 status=none | xxd -p -u | le2be | hex2deci)
echo $CLUSTERSECTORS

echo "Boot Sector: Size in Sectors of the Reserved Area" # 0x0E = 14 -> 2 bytes
RESERVEDSECTORS=$(dd if=boot-sector.dd bs=1 skip=14 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo $RESERVEDSECTORS

echo "Boot Sector: Number of FATs" # 0x10 = 16 -> 1 byte
FATNUM=$(dd if=boot-sector.dd bs=1 skip=16 count=1 status=none | xxd -p -u | le2be | hex2deci)
echo $FATNUM

echo "Boot Sector: Maximum Number of Files in the Root Directory" # 0x11 = 17 -> 2 bytes
ROOTDIRENTRIES=$(dd if=boot-sector.dd bs=1 skip=17 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo $ROOTDIRENTRIES

echo "Boot Sector: Size in Sectors of Each FAT" # 0x16 = 22 -> 2 bytes
FATSECTORS=$(dd if=boot-sector.dd bs=1 skip=22 count=2 status=none | xxd -p -u | le2be | hex2deci)
echo $FATSECTORS

# Sector Offset to root directory = (reserved space) + (FAT table size)×(number of FAT tables)
echo "Calculation: Sector Offset to Root Directory"
let "ROOTDIROFFSET = $RESERVEDSECTORS + $FATSECTORS * $FATNUM"
echo "$ROOTDIROFFSET sectors"

# Size of root directory = number of root directory entries x size of directory entry (32 bytes)
echo "Calculation: Size of Root Directory"
let "ROOTDIRSIZE = $ROOTDIRENTRIES * 32 / $SECTORSIZE"
echo "$ROOTDIRSIZE sectors"

echo "FAT16: Extracting Root Directory"
dd if=fat16.dd of=root-dir.dd bs=$SECTORSIZE skip=$ROOTDIROFFSET count=$ROOTDIRSIZE status=none

echo "FAT16: Extracting FAT Table" # Usually 2 FATs for redundancy
dd if=fat16.dd of=fat-table.dd bs=$SECTORSIZE skip=$RESERVEDSECTORS count=$FATSECTORS status=none

echo "Calculation: Sector Offset to Data Area"
let "DATAOFFSET = $ROOTDIROFFSET + $ROOTDIRSIZE"
echo "$DATAOFFSET sectors"

echo "Calculation: Size of Cluster"
let "CLUSTERSIZE = $CLUSTERSECTORS * $SECTORSIZE"
echo "$CLUSTERSIZE bytes"

echo "FAT16: Extracting Data Area"
dd if=fat16.dd of=data-area.dd bs=$SECTORSIZE skip=$DATAOFFSET status=none

function loop_dir_entries() { # Directory Image, Directory Enties (Num)
    DIRIMG=$1
    DIRENTRIES=$2
    if [ "$DIRENTRIES" == "0" ]; then # For convenience, calculate from DD image
        IMGSIZE="$(wc -c <"$DIRIMG")"
        let "DIRENTRIES = $IMGSIZE / 32"
    fi
    echo "Looping through directory image '$DIRIMG'..."
    # Loop through root directory entries
    for ((i = 0; i < DIRENTRIES; i++)); do # https://stackoverflow.com/a/171041

        dd if=$DIRIMG of=dir-entry.dd bs=32 skip=$i count=1 status=none

        FIRSTCHAR=$(dd if=dir-entry.dd bs=1 count=1 status=none | xxd -p -u)
        # 0x00: Unallocated, 0xE5: Deleted, Anything Else: First Character of File Name

        if [ "$FIRSTCHAR" == "00" ]; then # Unallocated
            :
        else
            echo -e "-> Directory Entry $i"
            if [ "$FIRSTCHAR" == "E5" ]; then # Deleted
                echo -e "\tDeleted File"
            fi

            # 0x01: read only, 0x02: hidden, 0x04: system, 0x08: volume label, 0x10: directory, 0x20: archive, 0x0F: long file name
            FILEATTR=$(dd if=dir-entry.dd skip=11 bs=1 count=1 status=none | xxd -p -u)
            echo -e "\tFile Attribute: $FILEATTR"

            if [ "$FILEATTR" == "0F" ]; then # Long file name
                # Sequence Number
                SEQNUM=$(dd if=dir-entry.dd bs=1 skip=0 count=1 status=none | xxd -p -u)
                # First 5 UCS-2 Characters | 0x1 = 1 -> 10 bytes
                UCS1=$(dd if=dir-entry.dd bs=1 skip=1 count=10 status=none | tr -d "\000")
                # Next 6 UCS-2 Characters | 0xE = 14 -> 12 bytes
                UCS2=$(dd if=dir-entry.dd bs=1 skip=14 count=12 status=none | tr -d "\000")
                # Next 2 UCS-2 Characters | 0x1B = 27 -> 4 bytes
                UCS3=$(dd if=dir-entry.dd bs=1 skip=27 count=4 status=none | tr -d "\000")
                LFN="$UCS1$UCS2$UCS3"
                LFN=$(echo "$LFN" | strings) # Filter non-ASCII characters
                echo -e "\tSequence Number: $SEQNUM"
                echo -e "\tLong File Name: $LFN"
            elif [ "$FILEATTR" == "10" ]; then # Directory
                DIRNAME=$(dd if=dir-entry.dd skip=0 bs=1 count=11 status=none)
                FIRSTCLUSTER=$(dd if=dir-entry.dd skip=26 bs=1 count=2 status=none | xxd -p -u | le2be | hex2deci)
                echo -e "\tDirectory Name: $DIRNAME"
                echo -e "\tFirst Cluster: $FIRSTCLUSTER"
            else
                FILENAME=$(dd if=dir-entry.dd skip=0 bs=1 count=11 status=none)
                FILESIZE=$(dd if=dir-entry.dd skip=28 bs=1 count=4 status=none | xxd -p -u | le2be | hex2deci)
                FIRSTCLUSTER=$(dd if=dir-entry.dd skip=26 bs=1 count=2 status=none | xxd -p -u | le2be | hex2deci)
                echo -e "\tFile Name: $FILENAME"
                echo -e "\tFile Size: $FILESIZE"
                echo -e "\tFirst Cluster: $FIRSTCLUSTER"
            fi
            echo
        fi
    done
}

loop_dir_entries "root-dir.dd" "$ROOTDIRENTRIES"

function extract_file() { # File Name, First Cluster, File Size
    FILENAME=$1
    FIRSTCLUSTER=$2
    FILESIZE=$3

    CURRCLUSTER=$FIRSTCLUSTER
    # https://stackoverflow.com/a/24421013
    while true; do
        NEXTCLUSTER=$(dd if=fat-table.dd bs=2 skip=$CURRCLUSTER count=1 status=none | xxd -p -u | le2be | hex2deci)

        # 0x0000: Unallocated, 0xFFF7: Bad sector, 0xFFF8: EOF
        if [ "$NEXTCLUSTER" == "0" ]; then
            echo "Cluster unallocated"
            break
        fi
        if [ "$NEXTCLUSTER" == "65527" ]; then
            echo "Bad sector"
            break
        fi

        # Data area starts numbering from 2
        let "ACTUALCLUSTER = $CURRCLUSTER - 1"
        let "SKIPCLUSTERS = $ACTUALCLUSTER - 1"

        # Append the file clusters into image
        dd if=data-area.dd bs=$CLUSTERSIZE skip=$SKIPCLUSTERS count=1 status=none >>$FILENAME.dd

        # 0xFFF8 (65528) >= End of File
        if [ "$NEXTCLUSTER" -ge "65528" ]; then
            if [ "$FILESIZE" == "0" ]; then
                echo "Extracted directory image '$FILENAME.dd'"
                break
            fi
            # Extract the actual file content
            dd if=$FILENAME.dd of=$FILENAME bs=1 count=$FILESIZE status=none
            echo "Extracted '$FILENAME'"
            break
        fi
        CURRCLUSTER=$NEXTCLUSTER
    done
}

extract_file "test.txt" "3" "104"

extract_file "folder" "4" "0" # Extracting a directory

loop_dir_entries "folder.dd" "0"

extract_file "ASCII_code_chart.png" "5" "37769"

# https://www.win.tue.nl/~aeb/linux/fs/fat/fat-1.html
# https://people.cs.umass.edu/~liberato/courses/2018-spring-compsci365+590f/lecture-notes/11-fats-and-directory-entries/
# https://people.cs.umass.edu/~liberato/courses/2018-spring-compsci365+590f/lecture-notes/12-demonstration-parsing-fat/
# ** Only Files, Directories, and LFNs are considered
# ** LFNs longer than 13 characters are not considered
# ** Assuming directories don't span more than 1 cluster
