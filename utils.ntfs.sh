#!/bin/bash

# NTFS Utilities: isolated to make main script cleaner

function extract_mft_entry() { # MFT Entry ID (0-)
    MFTENTRY=$1

    echo
    echo "NTFS: Extracting MFT Entry $MFTENTRY..."

    # MFT Entry is 1024 bytes

    # Offset to MFT in 1KB blocks (MFT entry size)
    let "MFTOFFSET1KB = $MFTOFFSET / 1024 + $MFTENTRY"

    dd if=ntfs.dd of=mft-entry.dd bs=1024 skip=$MFTOFFSET1KB count=1 status=none

    echo "-> MFT Entry $MFTENTRY"

    # Offset to first attribute: 0x14 = 20 -> 2 bytes
    ATTR1OFFSET=$(dd if=mft-entry.dd bs=1 skip=20 count=2 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\tOffset to First Attribute: $ATTR1OFFSET bytes"

}

function get_attribute_type() { # Attribute Type Identifier
    ATTRID=$1
    TYPESTR="-"
    # End Marker of Attributes: FFFF FFFF = 4294967295
    if [ "$ATTRID" == "4294967295" ]; then TYPESTR="End Marker of Attributes"; fi
    if [ "$ATTRID" == "16" ]; then TYPESTR="Standard Information"; fi
    if [ "$ATTRID" == "48" ]; then TYPESTR="File Name"; fi
    if [ "$ATTRID" == "80" ]; then TYPESTR="Security Descriptor"; fi
    if [ "$ATTRID" == "128" ]; then TYPESTR="Data"; fi
    echo "$TYPESTR"
}

function process_resident_attribute_content() { # Attribute Type Identifier
    ATTRID=$1
    echo -e "\t-> Resident Attribute"
    if [ "$ATTRID" == "128" ]; then # Data Attribute
        dd if=resident-attr-content.dd of=data.dd bs=1 status=none
        ATTRCONTENT=$(dd if=data.dd bs=1 status=none | tr -d "\000")
        echo -e "\t\tData Content (data.dd): $ATTRCONTENT"
    fi
    if [ "$ATTRID" == "48" ]; then # File Name Attribute
        # File reference of parent directory: 0x00 = 00 -> 6 byte (WITHOUT SEQUENCE)
        PARDIR=$(dd if=resident-attr-content.dd bs=1 skip=0 count=6 status=none | xxd -p -u | le2be | hex2deci)
        echo -e "\t\tParent Directory: $PARDIR"
        # File name length in unicode characters: 0x40 = 64 -> 1 byte
        UNILENGTH=$(dd if=resident-attr-content.dd bs=1 skip=64 count=1 status=none | xxd -p -u | le2be | hex2deci)
        echo -e "\t\tUnicode Length: $UNILENGTH characters"
        # Unicode is 2 bytes
        let "BYTELENGTH = $UNILENGTH * 2"
        # File name: 0x42 = 66 -> BYTELENGTH
        FILENAME=$(dd if=resident-attr-content.dd bs=1 skip=66 count=$BYTELENGTH status=none | tr -d "\000")
        echo -e "\t\tUnicode Filename: $FILENAME"
    fi
}

function process_non_resident_attribute() {
    echo -e "\t-> Non-Resident Attribute"
    # Starting Virtual Cluster Number (VCN) of the runlist: 0x10 = 16 -> 8 bytes
    VCNSTART=$(dd if=mft-entry-attr.dd bs=1 skip=16 count=8 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\t\tStarting VCN: $VCNSTART"
    # Ending VCN of the runlist: 0x18 = 24 -> 8 bytes
    VCNEND=$(dd if=mft-entry-attr.dd bs=1 skip=24 count=8 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\t\tEnding VCN: $VCNEND"
    # Offset to the runlist: 0x20 = 32 -> 2 bytes
    RUNLISTOFFSET=$(dd if=mft-entry-attr.dd bs=1 skip=32 count=2 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\t\tRunlist Offset: $RUNLISTOFFSET"
    # Compression unit size: 0x22 = 34 -> 2 bytes
    COMPUNIT=$(dd if=mft-entry-attr.dd bs=1 skip=34 count=2 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\t\tCompression Unit Size: $COMPUNIT"
    # Actual size of attribute content: 0x30 = 48 -> 8 bytes
    ACTSIZE=$(dd if=mft-entry-attr.dd bs=1 skip=48 count=8 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\t\tActual Size of Attr. Content: $ACTSIZE"
    # ------------------------------------------------------
    # Runlist Byte
    RUNBYTE=$(dd if=mft-entry-attr.dd bs=1 skip=$RUNLISTOFFSET count=1 status=none | xxd -u -p | hex2bin | padbin)
    echo -e "\t\tRunlist Byte: $RUNBYTE"
    # Run offset size: first 4 bytes in runlist byte
    RUNOFFSETSIZE=$(echo "$RUNBYTE" | cut -c1-4 | bin2deci)
    echo -e "\t\tRun Offset Size: $RUNOFFSETSIZE"
    # Run length size: last 4 bytes in runlist byte
    RUNLENGTHSIZE=$(echo "$RUNBYTE" | cut -c5-8 | bin2deci)
    echo -e "\t\tRun Length Size: $RUNLENGTHSIZE"
    # Run length: after runlist byte -> RUNLENGTHSIZE
    let "RUNLENGTHOFFSET = $RUNLISTOFFSET + 1"
    RUNLENGTH=$(dd if=mft-entry-attr.dd bs=1 skip=$RUNLENGTHOFFSET count=$RUNLENGTHSIZE status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\t\tRun Length: $RUNLENGTH"
    # Run offset: after run length -> RUNOFFSETSIZE
    let "RUNOFFSETOFFSET = $RUNLENGTHOFFSET + $RUNLENGTHSIZE"
    RUNOFFSET=$(dd if=mft-entry-attr.dd bs=1 skip=$RUNOFFSETOFFSET count=$RUNOFFSETSIZE status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\t\tRun Offset: $RUNOFFSET"
}

function extract_mft_entry_attribute() { # MFT Entry Offset (Bytes)
    ATTROFFSET=$1

    echo
    echo "-> MTF Entry Attribute @ Offset $ATTROFFSET Bytes"

    # Attribute Type: 0x00 = 0 -> 4 bytes
    # End Marker of Attributes: FFFF FFFF = 4294967295
    ATTRTYPE=$(dd if=mft-entry.dd bs=1 skip=$ATTROFFSET count=4 status=none | xxd -u -p | le2be | hex2deci)
    ATTRTYPESTR=$(get_attribute_type "$ATTRTYPE")
    echo -e "\tType: $ATTRTYPE ($ATTRTYPESTR)"

    # Attribute Size: 0x04 = 4 -> 4 bytes
    let "ATTRSIZEOFFSET = $ATTROFFSET + 4"
    ATTRSIZE=$(dd if=mft-entry.dd bs=1 skip=$ATTRSIZEOFFSET count=4 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\tSize: $ATTRSIZE"

    # Extract MTF entry attribute
    dd if=mft-entry.dd of=mft-entry-attr.dd bs=1 skip=$ATTROFFSET count=$ATTRSIZE status=none

    # Non-Resident Flag: 0x08 = 8 -> 1 byte
    NONRESFLAG=$(dd if=mft-entry-attr.dd bs=1 skip=8 count=1 status=none | xxd -u -p | le2be | hex2deci)
    echo -e "\tNon-Resident Flag: $NONRESFLAG"

    # Non resident attributes
    if [ "$NONRESFLAG" == "1" ]; then
        process_non_resident_attribute
    fi
    # Resident attributes
    if [ "$NONRESFLAG" == "0" ]; then
        # Size of content: 0x10 = 16 -> 4 bytes
        STREAMSIZE=$(dd if=mft-entry-attr.dd bs=1 skip=16 count=4 status=none | xxd -u -p | le2be | hex2deci)
        echo -e "\t[Resident] Size of Content: $STREAMSIZE"
        # Offset to content: 0x14 = 20 -> 2 bytes
        STREAMOFFSET=$(dd if=mft-entry-attr.dd bs=1 skip=20 count=2 status=none | xxd -u -p | le2be | hex2deci)
        echo -e "\t[Resident] Offset to Content: $STREAMOFFSET"
        # Extract resident atrribute content
        dd if=mft-entry-attr.dd of=resident-attr-content.dd bs=1 skip=$STREAMOFFSET count=$STREAMSIZE status=none

        process_resident_attribute_content "$ATTRTYPE"
    fi

    let "NEXTATTROFFSET = $ATTROFFSET + $ATTRSIZE"
    echo -e "\tNext Attribute Offset: $NEXTATTROFFSET"
}

function loop_mft_entry_attributes() { # Offset to first attribute
    OFFSETTOFIRST=$1
    extract_mft_entry_attribute "$OFFSETTOFIRST"
    while [ "$ATTRTYPE" != "4294967295" ]; do
        extract_mft_entry_attribute "$NEXTATTROFFSET"
    done
}

function list_mft_entry() { # Offset to first attribute
    MFTENTRY=$1
    extract_mft_entry "$MFTENTRY"
    if [ "$ATTR1OFFSET" == "0" ]; then
        echo "(!) No attributes"
        return
    fi
    loop_mft_entry_attributes "$ATTR1OFFSET"
}

function extract_file() { # Run Offset, Run Length, File Size, File Name
    RUNOFFSET=$1
    RUNLENGTH=$2
    FILESIZE=$3
    FILENAME=$4

    let "CLUSTERSIZEBYTES = $CLUSTERSECTORS * $SECTORSIZE"

    dd if=ntfs.dd of=file.dd bs=$CLUSTERSIZEBYTES skip=$RUNOFFSET count=$RUNLENGTH status=none
    # Truncate file
    dd if=file.dd of=$FILENAME bs=1 count=$FILESIZE status=none
    echo "Extracted '$FILENAME'"
}
