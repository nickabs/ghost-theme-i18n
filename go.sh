function list() {
  find ~/dev/www/themes/transmission -name "*hbs" |while read i
  do
    gawk '
    /{{t /  { printf("%s|",gensub(/.*\{\{t "(.*)"\}\}.*/,"\\1","g",$0)) }
    ' $i
  done
  echo
}
t=$(list |sed -e"s/|$//")


./locales.sh -l all -t "$t" -m
