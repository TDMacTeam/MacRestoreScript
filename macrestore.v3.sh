#!/bin/bash

function badDrive() {
	error "Reinstalled Failed!"
	error "Most likely a bad drive"
	afplay /System/Library/Sounds/Basso.aiff
	exit
}

function info() {
	echo "$(tput bold && tput setaf 6)$(date +%F_%T):$(tput sgr0) $(tput setaf 6)$1$(tput sgr0)"
}

function error() {
	echo "$(tput bold && tput setaf 1)$(date +%F_%T):$(tput sgr0) $(tput setaf 1)$1$(tput sgr0)"
}

function success() {
	echo "$(tput bold && tput setaf 2)$(date +%F_%T):$(tput sgr0) $(tput setaf 2)$1$(tput sgr0)"
}

function copy() {
	sudo asr -noverify -noprompt -source $1 -target /dev/disk0s2 -erase

	if [[ $? == 0 ]]; then
		success "Finished copy from disk2 to disk0s2"
		return 0
	fi

	error "Failed copy from disk2 to disk0s2"
	return 1
}

function partition() {
	diskutil partitiondisk /dev/disk0 GPT JHFS+ ERASED 0b
	if [[ $? == 0 ]]; then
		success "Finished partition on /dev/disk0"
		return 0
	fi

	error "Failed to partition /dev/disk0"
	return 1
}

function directErase() {
	diskutil eraseVolume JHFS+ ERASED /dev/disk0s2
	if [[ $? == 0 ]]; then
		success "Finished erasure of /dev/disk0s2"
		return 0
	fi

	error "Failed to erase /dev/disk0s2"
	error "May need to restart to continue"
	return 1
}

function unmount() {
	diskutil umount disk0s2
	if [[ $? == 0 ]]; then
		success "Finished unmount on disk0s2"
		return 0
	fi

	error "Failed to unmount disk0s2"
	return 1
}

# Main execution start
clear
echo "$(tput setaf 6 && tput bold)Mac OS Reinstaller$(tput sgr0)"

# Checks if the volume has previously been erased and skips it if so
volumeName=$(diskutil info /dev/disk0s2 | grep "Volume Name" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
volumeUsed=$(diskutil info /dev/disk0s2 | grep "Volume Used Space" | cut -d ":" -f2 | egrep -o '\(0.[1-9]+%\)')
echo $volumeName $volumeUsed
if [[ ($volumeName != "ERASED" && $volumeName != "Untitled") || $volumeUsed == "" ]]; then
	partition
	if [[ $? == 1 ]]; then
		# Erase /dev/disk0s2 directly
		directErase
		if [[ $? == 1 ]]; then badDrive; fi

		# The erasure worked, retry full disk
		partition
		# Failed a second time, drive is probably bad
		if [[ $? == 1 ]]; then badDrive; fi
	fi
else
	info "Drive already erased, skipping!"
fi

# TODO: Check if the image is mounted yet
# Attach the image
hdiutil attach /Users/test/Desktop/MacintoshHD.dmg
info "Disk image attached"

# Verify the image mounted properly
diskutil info /dev/disk2
if [[ $? == 1 ]]; then
	# Disk isn't mounted at /dev/disk2
	error "Disk image is not mounted at /dev/disk2"
	error "Please fix and restart the script"
	exit
fi

volumeName=$(diskutil info /dev/disk2 | grep "Volume Name" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
volumeType=$(diskutil info /dev/disk2 | grep "Protocol" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')

# Detect if the image is mounted at /dev/disk2
if [[ $volumeName != "Macintosh HD" || $volumeType != "Disk Image" ]]; then
	# It's not at /dev/disk2, let's find it
	volumes=$(diskutil list | grep -A 3 "(disk image)" | grep 0: | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//' | cut -c 1-12)
	if [[ $volumes != "Macintosh HD" ]]; then
		# There's nothing that matches, so quit
		error "Unable to find image mount point!"
		exit
	else
		mountPoint=$(diskutil list | grep -A 3 "(disk image)" | grep /dev/disk | cut -c 1-10)
	fi
else
	mountPoint="/dev/disk2"
fi

# Copy the drive image over
copy $mountPoint
# Image copy failed, don't continue
if [[ $? == 1 ]]; then exit; fi

# Not sure why this is here, but Jayson put it here, so we're leaving it
sleep 3
unmount
diskutil mount disk0s2
sleep 7

# Configure the drive to be the boot drive
sudo systemsetup -setstartupdisk /Volumes/Macintosh\ HD\ 1/System/Library/CoreServices

# We're done
unmount
clear
success "Complete"
afplay /System/Library/Sounds/Ping.aiff
