if [ -z "$1" ]; then
  echo "Specify the SVG file to convert: $0 file.svg - will convert file.svg to file.hpgl"
  exit 1
fi
java -cp "bin:lib/saxon9he.jar:lib/saxon9-xqj.jar" app.SVG2Plot $1 $1.hpgl 2> /dev/null
