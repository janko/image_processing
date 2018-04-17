#!/bin/bash

set -e

export VIPS_HOME=$HOME/libvips
export PATH=$VIPS_HOME/bin:$PATH
export LD_LIBRARY_PATH=$VIPS_HOME/lib:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$VIPS_HOME/lib/pkgconfig:$PKG_CONFIG_PATH
export GI_TYPELIB_PATH=$VIPS_HOME/lib/girepository-1.0/

vips_site=https://github.com/jcupitt/libvips/releases/download
vips_version_major=8
vips_version_minor=6
vips_version_patch=3
version=$vips_version_major.$vips_version_minor.$vips_version_patch

# return early if we've already built this version of libvips
if [ -d "$VIPS_HOME/bin" ]; then
  installed_version=$(vips --version)
  escaped_version="$vips_version_major\.$vips_version_minor\.$vips_version_patch"
  if [[ "$installed_version" =~ ^vips-$escaped_version ]]; then
    echo "Using cached directory"
    exit 0
  fi
fi

rm -rf $VIPS_HOME

wget $vips_site/v$version/vips-$version.tar.gz
tar zvxf vips-$version.tar.gz
cd vips-$version
./configure --prefix=$VIPS_HOME $*
make & make install
