# svg2hpgl
XSLT based conversion of SVG into HPGL/1 plot commands

## How to use: ##
On Unixish systems (MacOSX, Linux) clone this repo, then from inside run ./svg2hpgl.sh *inputfile.svg* to convert the given inputfile.svg into a HPGL file which can be sent to a plotter for output or viewed in a HPGL viewer.

This has been tested with SVG files saved from Adobe Illustrator.

## What it is: ##
Main part is a XSLT stylesheet that defines tranformations from svg: elements into HPGL text. As such this should be platform neutral and needs a XSLT3 compatible XSL engine, the saxon9 opensource Java one is included in the lib folder.

The code is optimized for output on a HP7475A or similar pen plotter, mileage on other devices may vary. It should be straight forward to adapt to other requirements.

Pen selection is derived from the fill/stroke colors and mapped such that the default 7475A carousel setup should work.

Requires a installed Java VM or a JDK in case you wish to compile from source.
