#!/bin/bash

# Package a root filesystem directory into a filesystem image file

source sources/include.sh || exit 1

# Parse the sources/targets/$1 directory

read_arch_dir "$1"

# Which directory do we package up?

if [ -z "$NATIVE_ROOT" ]
then
  [ -z "$NO_NATIVE_COMPILER" ] &&
    NATIVE_ROOT="$BUILD/root-filesystem-$ARCH"

  [ -e "$NATIVE_ROOT" ] ||
    NATIVE_ROOT="$BUILD/simple-root-filesystem-$ARCH"
fi

if [ ! -d "$NATIVE_ROOT" ]
then
  [ -z "$FAIL_QUIET" ] && echo No "$NATIVE_ROOT" >&2
  exit 1
fi

[ -z "$SYSIMAGE_TYPE" ] && SYSIMAGE_TYPE=squashfs

echo "Generating $SYSIMAGE_TYPE root filesystem from $NATIVE_ROOT."

# Embed an initramfs image in the kernel?

if [ "$SYSIMAGE_TYPE" == "initramfs" ]
then
  $CC "$SOURCES/toys/gen_init_cpio.c" -o my_gen_init_cpio || dienow
  ./my_gen_init_cpio <(
      "$SOURCES"/toys/gen_initramfs_list.sh "$NATIVE_ROOT" || dienow
      [ ! -e "$NATIVE_ROOT"/init ] &&
        echo "slink /init /sbin/init.sh 755 0 0"
      [ ! -d "$NATIVE_ROOT"/dev ] && echo "dir /dev 755 0 0"
      echo "nod /dev/console 660 0 0 c 5 1"
    ) > "$STAGE_DIR/initramfs_data.cpio" || dienow
  echo Initramfs generated.

elif [ "$SYSIMAGE_TYPE" == "ext2" ]
then
  # Generate a 64 megabyte ext2 filesystem image from the $NATIVE_ROOT
  # directory, with a temporary file defining the /dev nodes for the new
  # filesystem.

  [ -z "$SYSIMAGE_HDA_MEGS" ] && SYSIMAGE_HDA_MEGS=64

  echo "/dev d 755 0 0 - - - - -" > "$WORK/devs" &&
  echo "/dev/console c 640 0 0 5 1 0 0 -" >> "$WORK/devs" &&

  # Produce a filesystem with the currently used space plus 20% for filesystem
  # overhead, which should always be big enough.

  BLOCKS=$[1024*(($(du -m -s "$NATIVE_ROOT" | awk '{print $1}')*12)/10)]
  [ $BLOCKS -lt 4096 ] && BLOCKS=4096

  genext2fs -z -D "$WORK/devs" -d "$NATIVE_ROOT" -b $BLOCKS -i 1024 \
    "$STAGE_DIR/hda.ext2" &&
  rm "$WORK/devs" || dienow

  # Extend image size to HDA_MEGS if necessary, keeping it sparse.  (Feeding
  # a larger -b size to genext2fs is insanely slow, and not particularly
  # sparse.)

  echo "$(stat -c %s "$STAGE_DIR/$IMAGE") -lt $SYSIMAGE_HDA_MEGS"

  if [ ! -z "$SYSIMAGE_HDA_MEGS" ] &&
     [ $((`stat -c %s "$STAGE_DIR/$IMAGE"` / (1024*1024) )) -lt "$SYSIMAGE_HDA_MEGS" ]
  then
    echo resizing image to $SYSIMAGE_HDA_MEGS
    dd if=/dev/zero of="$STAGE_DIR/$IMAGE" bs=1k count=1 seek=$[1024*1024-1] &&
    resize2fs "$STAGE_DIR/$IMAGE" ${SYSIMAGE_HDA_MEGS}M || dienow
    echo resize complete
  fi

elif [ "$SYSIMAGE_TYPE" == "squashfs" ]
then
  mksquashfs "${NATIVE_ROOT}" "$STAGE_DIR/hda.sqf" -noappend -all-root \
    ${FORK:+-no-progress} -p "/dev d 755 0 0" \
    -p "/dev/console c 666 0 0 5 1" || dienow
else
  echo "Unknown image type $SYSIMAGE_TYPE" >&2
  dienow
fi

create_stage_tarball

echo Image generation complete.