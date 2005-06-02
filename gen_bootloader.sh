#!/bin/bash

set_bootloader() {
	if [ "x$BOOTLOADER" == 'xgrub' ]
	then
		set_grub_bootloader
	else
		return 0
	fi
}

set_grub_bootloader() {
	local GRUB_CONF='/boot/grub/grub.conf'

	print_info 1 ''
	print_info 1 "Adding kernel to $GRUB_CONF..."

	# Extract block device information from /etc/fstab
	local GRUB_ROOTFS=$(awk '/[[:space:]]\/[[:space:]]/ { print $1 }' /etc/fstab)
	local GRUB_BOOTFS=$(awk '/^[^#].+[[:space:]]\/boot[[:space:]]/ { print $1 }' /etc/fstab)

	# If /boot is not defined in /etc/fstab, it must be the same as /
	[ "x$GRUB_BOOTFS" == 'x' ] && GRUB_BOOTFS=$GRUB_ROOTFS

	# Translate block letters into grub numbers
	local GRUB_ROOT_DISK=$(echo $GRUB_ROOTFS | sed -e 's/\/dev\/[hsm]d\([[:alpha:]]\)[[:digit:]]\+/\1/')
	case $GRUB_ROOT_DISK in
		a )
			GRUB_ROOT_DISK='0' ;;
		b )
			GRUB_ROOT_DISK='1' ;;
		c )
			GRUB_ROOT_DISK='2' ;;
		d )
			GRUB_ROOT_DISK='3' ;;
		e )
			GRUB_ROOT_DISK='4' ;;
	esac

	# Translate partition numbers into grub numbers
	local GRUB_ROOT_PARTITION=$(echo $GRUB_BOOTFS | sed -e 's/\/dev\/[hsm]d[[:alpha:]]\([[:digit:]]\+\)/\1/')

	# Create grub configuration directory and file if it doesn't exist.
	[ ! -e `basename $GRUB_CONF` ] && mkdir -p `basename $GRUB_CONF`

	if [ ! -e $GRUB_CONF ]
	then
		# Check that $GRUB_ROOT_PARTITION is a single character
		local GRUB_ROOT_PARTITION_TEST=$(printf $GRUB_ROOT_PARTITION | wc -c)
		if [ "${GRUB_ROOT_PARTITION_TEST}" -ne '1' ]
			# GRUB_ROOT_PARTITION is not a number; we can't work this out so... error
			print_error 1 'Error! /boot/grub/grub.conf does not exist and the correct settings can't be automatically detected.'
			print_error 1 'Please manually create your /boot/grub/grub.conf file.'
		else
			# grub.conf doesn't exist - create it with standard defaults
			touch $GRUB_CONF
			echo 'default 0' >> $GRUB_CONF
			echo 'timeout 5' >> $GRUB_CONF
			echo "" >> $GRUB_CONF

			# Add grub configuration to grub.conf	
			echo "# Genkernel generated entry, see GRUB documentation for details" >> $GRUB_CONF
			echo "title=Gentoo Linux ($KV)" >> $GRUB_CONF
			echo -e "\troot (hd$GRUB_ROOT_DISK,$GRUB_ROOT_PARTITION)" >> $GRUB_CONF
			if [ "${BUILD_INITRD}" -eq '0' ]
			then
				echo -e "\tkernel /kernel-$KV root=$GRUB_ROOTFS" >> $GRUB_CONF
			else
				echo -e "\tkernel /kernel-$KV root=/dev/ram0 init=/linuxrc real_root=$GRUB_ROOTFS" >> $GRUB_CONF
				echo -e "\tinitrd /initrd-$KV" >> $GRUB_CONF
			fi
			echo "" >> $GRUB_CONF
		fi
	else
		# grub.conf already exists; so...
		# ... Clone the first boot definition and change the version.
		cp $GRUB_CONF $GRUB_CONF.bak
		awk 'BEGIN { RS="" ; FS="\n" ; OFS="\n" ; ORS="\n\n" } 
			NR == 2 {
				ORIG=$0;
				sub(/\(.+\)/,"(" KV ")",$1);
				sub(/kernel-[[:alnum:][:punct:]]+/, "kernel-" KV, $3);
				sub(/initrd-[[:alnum:][:punct:]]+/, "initrd-" KV, $4);
				print RS $0; 
				print RS ORIG;}
			NR != 2 { print RS $0; }' KV=$KV $GRUB_CONF.bak > $GRUB_CONF
	fi
}
