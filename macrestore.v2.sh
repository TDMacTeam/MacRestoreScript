#!/bin/bash
_now=$(date +%Y-%m-%d_%H:%m:%d)

Diskutil partitiondisk /dev/disk0 GPT JHFS+ ERASED 0b
if [ "$?" -eq "0" ]
then
    echo "$_now: Finished partition on /dev/disk0"
else
    echo "$_now: Failed to partition /dev/disk0"
    exit
fi

hdiutil attach /Users/test/Desktop/MacintoshHD.dmg

sudo asr -noverify -noprompt -source /dev/disk2 -target /dev/disk0s2 -erase
if [ "$?" -eq "0" ]
then
    echo "$_now: Finished copy from disk2 to disk0s2"
else
    echo "$_now: Failed to copy from disk2 to disk0s2"
    exit
fi

sleep 3

diskutil umount disk0s2
if [ “$?” -eq "0" ]
then
    echo "$_now: Finished unmount on disk0s2"
else
    echo "$_now: Failed to unmount disk0s2"
    exit
fi

diskutil mount disk0s2

sleep 7

sudo systemsetup -setstartupdisk /Volumes/Macintosh\ HD\ 1/System/Library/CoreServices

diskutil umount disk0s2