# File System Forensics

This repository includes reusable scripts derived from the practical work carried out for 'SCS 4213: Digital Forensics' course at UCSC.

All the scripts are written in Bash.

You may need to install some commands if your Linux distribution does not have them already installed. (e.g. dd, bc etc.)
The commands used in the scripts are _generally_ available on any distro.
If you are getting errors on running things, install missing tools as required.

## What Can I Do With This?


For starters run, 
* `mbr.sh` to analyze the MBR entries on a disk.
* `fat16.sh` to analyze a FAT16 partition image.
* `ntfs.sh` to analyze a NTFS partition image.

A bunch of sample images are given by default.

The scripts itself are self-explanatory
(However, you need to know how to read bash scripts).

If you do not understand anything here, this repository is probably not what you are looking for.

## Reference Material

File System Forensic Analysis - Brian Carrier
