## HEAD

* [minimagick] Use `-thumbnail` instead of `-resize` in `#resize_*` methods (@janko-m)

* [minimagick] Add loader and saver options (@janko-m)

## 0.10.3 (2018-03-24)

* [minimagick] Fix bang methods in deprecated API calling nondestructive versions (@janko-m)

## 0.10.2 (2018-03-22)

* [minimagick] Add back default offset arguments to deprecated `#crop` (@janko-m)

## 0.10.1 (2018-03-22)

* [minimagick] Don't print deprecation warning for old API twice when IO objects are used (@janko-m)

## 0.10.0 (2018-03-21)

* [minimagick] Rewrite MiniMagick module to use the chainable API (@janko-m)

* [minimagick] Deprecate the old API (@janko-m)

* [minimagick] Raise an exception on processing warnings (@janko-m)

* [minimagick] Speed up `.valid_image?` by an order of magnitude (@janko-m)

* [minimagick] Don't accept arbitrary IO object anymore (@janko-m)

* [minimagick] Removed unnecessary `#crop` and `#resample` macros (@janko-m)

* [vips] Ignore undefined loader/saver options (@janko-m)

* [vips] Preserve transparent background in `#resize_to_pad` (@janko-m)

* [vips] Remove the ability to specify colors using names (@janko-m)

* [minimagick, vips] Autorotate images after loading them (@janko-m)

* [core] Delete result `Tempfile` object in case of processing errors (@janko-m)

* [core] Allow returning `nil` in the `#custom` block (@janko-m)

* [core] Allow specifying a path string as source file (@janko-m)

* [core] Allow saving to a specific location with the `:destination` call option (@janko-m)

## 0.9.0 (2018-03-16)

* Added libvips module (@GustavoCaso, @janko-m)

* Drop official support for MRI 2.0 and 2.1

## 0.4.5 (2017-09-08)

* Add `lib/image_processing.rb` to allow loading via `Bundler.require` (@printercu)

## 0.4.4 (2017-06-16)

* Fix last changes being incompatible with older Ruby versions, again (@janko-m)

## 0.4.3 (2017-06-16)

* Fix last changes being incompatible with older Ruby versions (@janko-m)

## 0.4.2 (2017-06-16)

* Don't use path of input file as basename for output file (@janko-m)

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
