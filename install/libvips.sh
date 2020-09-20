vips_site=https://github.com/libvips/libvips/releases/download
version=8.10.1

sudo apt-get install -y gobject-introspection libgirepository1.0-dev libglib2.0-dev libpoppler-glib-dev
curl -OL $vips_site/v$version/vips-$version.tar.gz
tar zvxf vips-$version.tar.gz && cd vips-$version && ./configure && sudo make && sudo make install
export GI_TYPELIB_PATH=/usr/local/lib/girepository-1.0/
sudo ldconfig
