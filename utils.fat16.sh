#!/bin/bash

# FAT16 Utilities: isolated to make main script cleaner

function list_dir_entries() { # Directory Image, Directory Enties (Num)
    DIRIMG=$1
    DIRENTRIES=$2
    if [ "$DIRENTRIES" == "0" ]; then # For convenience, calculate from DD image
        IMGSIZE="$(wc -c <"$DIRIMG")"
        let "DIRENTRIES = $IMGSIZE / 32"
    fi
    echo "Listing directory entries in image '$DIRIMG'..."
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

function extract_deleted_file() { # File Name, First Cluster, File Size
    FILENAME=$1
    FIRSTCLUSTER=$2
    FILESIZE=$3

    # Data area starts numbering from 2
    let "ACTUALCLUSTER = $FIRSTCLUSTER - 1"
    let "SKIPCLUSTERS = $ACTUALCLUSTER - 1"

    let "QUOTIENT = $FILESIZE / $CLUSTERSIZE"
    let "REMAINDER = $FILESIZE % $CLUSTERSIZE"
    if [ "$REMAINDER" != "0" ]; then
        let "QUOTIENT = $QUOTIENT + 1"
    fi

    if [ "$FILESIZE" == "0" ]; then
        QUOTIENT=1
    fi

    dd if=data-area.dd of=$FILENAME.dd bs=$CLUSTERSIZE skip=$SKIPCLUSTERS count=$QUOTIENT status=none
    # Truncate slack
    dd if=$FILENAME.dd of=$FILENAME bs=1 count=$FILESIZE status=none
    echo "Extracted deleted '$FILENAME'"
}

function list_cluster_chains() {
    VISITEDCLUSTERS=()
    # A cluster number is 2 bytes in FAT
    # Calculate max clusters possible in FAT
    let "ALLCLUSTERS = ($FATSECTORS * $SECTORSIZE) / 2"
    for ((CLUSTER = 2; CLUSTER < ALLCLUSTERS; CLUSTER++)); do      # 0, 1 not needed
        if [[ " ${VISITEDCLUSTERS[*]} " =~ " ${CLUSTER} " ]]; then # https://stackoverflow.com/a/15394738
            continue
        fi
        CURRCLUSTER="$CLUSTER"
        PRINTCHAIN=1 # Print cluster chain
        while true; do
            NEXTCLUSTER=$(dd if=fat-table.dd bs=2 skip=$CURRCLUSTER count=1 status=none | xxd -p -u | le2be | hex2deci)
            if [ "$NEXTCLUSTER" == "0" ]; then
                break
            fi
            if [ "$NEXTCLUSTER" == "65527" ]; then
                break
            fi
            if [ "$PRINTCHAIN" == "1" ]; then
                echo -ne "\nCluster Chain: "
                PRINTCHAIN=0
            fi
            echo -n "$CURRCLUSTER "
            VISITEDCLUSTERS+=("$CURRCLUSTER")
            CURRCLUSTER="$NEXTCLUSTER"
            if [ "$NEXTCLUSTER" -ge "65528" ]; then
                break
            fi
        done
    done
}
