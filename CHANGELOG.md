## 0.4.1 (2016-09-08)

* Maintain transparent background of PNGs in `#resize_to_fill` (janko-m)

## 0.4.0 (2016-11-07)

* Add `#corrupted?` for checking whether an image is corrupted (janko-m)

## 0.3.0 (2016-05-03)

* Add cropping functionality to `ImageProcessing::MiniMagick` (paulgoetze)

## 0.2.5 (2016-03-24)

* Rewind the file after making a copy in non-destructive methods (janko-m)

* Add ability to supply page number to `#convert` (janko-m)

## 0.2.4 (2015-10-21)

* Don't error when checking MiniMagick version for older versions of MiniMagick (janko-m)

## 0.2.3 (2015-10-17)

* Fix uploading tempfiles to S3 using aws-sdk (janko-m)

* Make nondestructive methods available on class methods on `ImageProcessing::MiniMagick` (janko-m)

## 0.2.2 (2015-10-04)

* Make `ImageProcessing::MiniMagick#with_minimagick` public (janko-m)

* Add `ImageProcessing::MiniMagick#auto_orient` (janko-m)

## 0.2.1 (2015-10-03)

* Include the actual code in the gem (janko-m)

## 0.2.0 (2015-10-03)

* Add `ImageProcessing::MiniMagick#resample` for changing resolution (janko-m)

* Fix padding in `ImageProcessing::MiniMagick#resize_and_pad` (janko-m)
