#!/bin/bash

set -e

export MAGICK_HOME=$HOME/ImageMagick
export PATH=$MAGICK_HOME/bin:$PATH
export LD_LIBRARY_PATH=$MAGICK_HOME/lib:$LD_LIBRARY_PATH

magick_site=http://www.imagemagick.org/download

# return early if we've already built ImageMagick
if [ -d "$MAGICK_HOME/bin" ]; then
  echo "Using cached directory"
  exit 0
fi

rm -rf $MAGICK_HOME

wget $magick_site/ImageMagick.tar.gz
tar zvxf ImageMagick.tar.gz
cd ImageMagick-7.*
./configure --prefix=$MAGICK_HOME $*
make & make install
