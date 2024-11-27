
Before running the script you first need to convert all your hardcoded theme strings using the translation helper, for instance:
```html
<a href="#/portal/signup" data-portal="signup">{{t "Subscribe"}}</a>
```

Read the Ghost developer guide on translations [here](https://ghost.org/docs/themes/helpers/translate/).  

The script will run on macos (you will need to install gawk (`brew gawk`)) or linux. To run the script

```
clone git@github.com:nickabs/ghost-theme-i18n.git
cd ghost-theme-i18n
mkdir tmp
bash locale.sh

USAGE: ./locales.sh [-c ] [ -a ] [ -t string ] [ -l locale ] [ -fm ]
    Options:
      -r repos    clone/pull repos to tmp
      -t string   string to translate (you can send mulitple strings separated by '|')
      -l locale   locale  (use 'all' to get all available translations)
      -f          fuzzy match (exact match otherwise)
      -m          make the locale json files in tmp/locales
      -a          report on coverage in previously created locale files
      -e          make locales with every available translation string
```

Once you have converted all the text sttrings you can then run the script (see usage statement above) with a -t parameter that lists all the strings you want to translate.

the script will create a candidate set of locales in `tmp/locales` based on the translations extracted from a number of ghost public repositories.  These repos are hardcoded in the script - feel free to add your own or to change the priority order

The script will check for previously translated strings for the locale specified and include them in the created locale files.  If the string has not been translated previously, a placeholder entry will be created (in thesse cases the English version will still show in your theme until you manually add a suitable translation)

a crude way to automate this process is below.  Bear in mind you will lose any manually completed translations if you overwrite existing locales with the output of this script

```bash
function list() {
  find /your-directory/theme-name -name "*hbs" |while read i
  do
    gawk '
    /{{t /  { printf("%s|",gensub(/.*\{\{t "(.*)"\}\}.*/,"\\1","g",$0)) }
    ' $i
  done
  echo
}
t=$(list |sed -e"s/|$//")


./locales.sh -l all -t "$t" -m
```