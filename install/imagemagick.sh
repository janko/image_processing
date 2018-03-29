wget http://www.imagemagick.org/download/ImageMagick.tar.gz
tar -xvf ImageMagick.tar.gz
cd ImageMagick-7.*
./configure
make
sudo make install
sudo ldconfig /usr/local/lib
