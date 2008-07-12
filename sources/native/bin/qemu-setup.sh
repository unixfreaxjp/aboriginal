#!/tools/bin/bash

# If you're doing a Linux From Scratch build, the /tools directory is
# sufficient.  (Start by installing kernel headers and building a C library.)

# Otherwise, building source packages wants things like /bin/bash and
# running the results wants /lib/ld-uClibc.so.0, so set up some directories
# and symlinks to let you easily compile source packages.

# Create some temporary directories at the root level
mkdir -p /{proc,sys,etc,tmp}
[ ! -e /bin ] && ln -s /tools/bin /bin
[ ! -e /lib ] && ln -s /tools/lib /lib

# Populate /dev
mount -t sysfs /sys /sys
mount -t tmpfs /dev /dev
mdev -s

# Mount /proc is there
mount -t proc /proc /proc

# If we're running under qemu, do some more setup
if [ `echo $0 | sed 's@.*/@@'` == "qemu-setup.sh" ]
then

  # Note that 10.0.2.2 forwards to 127.0.0.1 on the host.

  # Setup networking for QEMU (needs /proc)
  echo "nameserver 10.0.2.3" > /etc/resolv.conf
  ifconfig eth0 10.0.2.15
  route add default gw 10.0.2.2

  # If we have no RTC, try rdate instead:
  [[ `date +%s` < 1000 ]] && rdate 10.0.2.2 # or time-b.nist.gov

  # If there's a /dev/hdb or /dev/sdb, mount it on home

  [ -b /dev/hdb ] && HOMEDEV=/dev/hdb
  [ -b /dev/sdb ] && HOMEDEV=/dev/sdb
  if [ ! -z "$HOMEDEV" ]
  then
    mkdir -p /home
    mount $HOMEDEV /home
    export HOME=/home
  fi
fi

# Switch to a shell with command history.
exec /tools/bin/busybox ash
