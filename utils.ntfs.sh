#!/bin/bash

# NTFS Utilities: isolated to make main script cleaner

function extract_mft_entry() { # MFT Entry ID (0-)
    MFTENTRY=$1

    echo
    echo "NTFS: Extracting MFT Entry $MFTENTRY..."

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

    let "NEXTATTROFFSET = $ATTROFFSET + $ATTRSIZE"
    echo -e "\tNext Attribute Offset: $NEXTATTROFFSET"
}
