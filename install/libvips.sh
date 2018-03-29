vips_site=https://github.com/jcupitt/libvips/releases/download
version=8.6.3

sudo apt-get install -y gobject-introspection libgirepository1.0-dev libglib2.0-dev libpoppler-glib-dev
curl -OL $vips_site/v$version/vips-$version.tar.gz
tar zvxf vips-$version.tar.gz && cd vips-$version && ./configure && sudo make && sudo make install
export GI_TYPELIB_PATH=/usr/local/lib/girepository-1.0/
sudo ldconfig
