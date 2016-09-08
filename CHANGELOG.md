## 0.4.1 (08-09-2016)

* Maintain transparent background of PNGs in `#resize_to_fill` (janko-m)

## 0.4.0 (11-07-2016)

* Add `#corrupted?` for checking whether an image is corrupted (janko-m)

## 0.3.0 (03-05-2016)

* Add cropping functionality to `ImageProcessing::MiniMagick` (paulgoetze)

## 0.2.5 (24-03-2016)

* Rewind the file after making a copy in non-destructive methods (janko-m)

* Add ability to supply page number to `#convert` (janko-m)

## 0.2.4 (21-10-2015)

* Don't error when checking MiniMagick version for older versions of MiniMagick (janko-m)

## 0.2.3 (17-10-2015)

* Fix uploading tempfiles to S3 using aws-sdk (janko-m)

* Make nondestructive methods available on class methods on `ImageProcessing::MiniMagick` (janko-m)

## 0.2.2 (04-10-2015)

* Make `ImageProcessing::MiniMagick#with_minimagick` public (janko-m)

* Add `ImageProcessing::MiniMagick#auto_orient` (janko-m)

## 0.2.1 (03-10-2015)

* Include the actual code in the gem (janko-m)

## 0.2.0 (03-10-2015)

* Add `ImageProcessing::MiniMagick#resample` for changing resolution (janko-m)

* Fix padding in `ImageProcessing::MiniMagick#resize_and_pad` (janko-m)
