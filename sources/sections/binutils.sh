# Build binutils, c wrapper, and uClibc++

# Build binutils, which provides the linker and assembler and such.

# PROGRAM_PREFIX affects the name of the generated tools, ala "${ARCH}-".

setupfor binutils

# The binutils ./configure stage is _really_stupid_, and we need to define
# lots of environment variables to make it behave.

function configure_binutils()
{
  "$CURSRC/configure" --prefix="$STAGE_DIR" \
    --build="$CROSS_HOST" --host="$FROM_HOST" --target="$CROSS_TARGET" \
    --disable-nls --disable-shared --disable-multilib --disable-werror \
    --with-lib-path=lib --program-prefix="$PROGRAM_PREFIX" $BINUTILS_FLAGS

  [ $? -ne 0 ] && dienow
}

if [ -z "$FROM_ARCH" ]
then
  # Create a simple cross compiler, from this host to target $ARCH.
  # This has no prerequisites.

  # The binutils ./configure stage is _really_stupid_.  Define lots of
  # environment variables to make it behave.

  AR=ar AS=as LD=ld NM=nm OBJDUMP=objdump OBJCOPY=objcopy configure_binutils
else
  # Canadian cross for an arbitrary host/target.  The new compiler will run
  # on $FROM_ARCH as its host, and build executables for $ARCH as its target.
  # (Use host==target to produce a native compiler.)  Doing this requires
  # existing host ($FROM_ARCH) _and_ target ($ARCH) cross compilers as
  # prerequisites.

  AR="${FROM_ARCH}-ar" CC="${FROM_ARCH}-cc" configure_binutils
fi

# Now that it's configured, build and install binutils

make -j $CPUS configure-host &&
make -j $CPUS CFLAGS="-O2 $STATIC_FLAGS" &&
make -j $CPUS install &&

# Fix up install

mkdir -p "$STAGE_DIR/include" &&
cp "$CURSRC/include/libiberty.h" "$STAGE_DIR/include" &&

# ln -sf ../../../../tools/bin/ld  ${STAGE_DIR}/libexec/gcc/*/*/collect2 || dienow

cleanup build-binutils