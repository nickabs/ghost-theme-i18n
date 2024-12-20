#!/bin/bash
function usage() {
    echo "USAGE: $0 [ -e ] [ -t string  -l locale ] [ -fm ] [-c ] [ -a ]
    Options:
      -r repos    clone/pull repos to $TMPDIR
      -t string   string to translate (you can send mulitple strings separated by '|')
      -e          when used instead of -t, this will create a summary of every available translation string 
      -l locale   locale  (use 'all' to get all available translations)
      -f          fuzzy match (exact match otherwise)
      -m          make the locale json files in $LOCALESDIR (the script displays to stdout otherwise)
      -a          report on coverage in previously created locale files
      " >&2
    exit 1
}

function listRepos() {
    # highest priority first 
    echo "
    git@github.com:TryGhost/Ghost.git
    git@github.com:SourceTheme-i18n/Source.git
    git@github.com:eddiesigner/liebling.git
    git@github.com:juan-g/WorldCasper2.git
    git@github.com:godofredoninja/simply.git
    git@github.com:godofredoninja/Mapache.git
    git@github.com:GenZmeY/casper-i18n.git
    git@github.com:zutrinken/attila.git
"
}

function repos() {
    for repo in $(listRepos) 
    do
        gitdir=$(echo $repo |gawk '{  printf("%s/%s",tmpdir,gensub(/.*\/(.*).git/,"\\1","g", $0)) }' tmpdir=$TMPDIR)
        if [ -d "$gitdir" ]; then
            cd $gitdir ; git pull ; cd -
        else
            git clone $repo $gitdir
        fi
    done
}

function listLocales() {
     find  ${TMPDIR}/Ghost/ghost/i18n/locales/ -type d |grep -v ${TMPDIR}/en |sed -e "s#.*/##"
}

# list the files in priorty order
function listLocaleFiles () {
    l=$1
    find $TMPDIR/Ghost/ghost/i18n/locales/$l -type f
    for repo in $(listRepos)
    do
        gitdir=$(echo $repo |gawk '{  printf("%s/%s",tmpdir,gensub(/.*\/(.*).git/,"\\1","g", $0)) }' tmpdir=$TMPDIR)
        find $gitdir -name $l.json 
    done
}

function tFormat() {
      gawk '/"[[:space:]]*:/ {
            gsub(/\|/,"")
            gsub(/"[[:space:]]*:/,"|")
            gsub(/[[:space:]]*[^\\]"|"[[:space:]]*,$|/, "")
            printf("%s|%s|%s\n", $0, FILENAME, l) 
      } ' l="$2" $1
}

function tMatch() {
    # input: from|to|source|locale .eg:
    # Sign in|Se connecter|tmp/Ghost/ghost/i18n/locales/fr/ghost.json|fr
    #

    gawk ' BEGIN { FS="|" } { 
        from=$1; to=$2; source=$3; locale=$4
        t=sprintf("%s§%s§%s",from, to, source)
        d=sprintf("%s§%s", from, locale) # when deduping remove repeated translations of the same string in a single locale

        if (! to && locale != "en") 
            next

        if (dedupe) 
            if (da[d]) 
                next
            else 
                da[d]="true"

        s=sprintf("%s§%s", source, locale)
        a[t]=s  # array of translation pairs
    }
    END { 
        if (item == "all") {
            for (t in a) {
                split(t,tt,"§") ; from=tt[1] ; to=tt[2] ; source=tt[$3]
                split(a[t],att,"§") ; source=att[1] ; locale=att[2]
                if (locale == "en")
                    to=""
                printf("%s|%s|\"%s\"|\"%s\"\n", locale, source, from, to )
            }
            exit
        }

        split(item,items,"|") 
        for (i in items) {
            thisitem=items[i]
            for (t in a) {
                split(t,tt,"§") ; from=tt[1] ; to=tt[2] ; source=tt[$3]
                split(a[t],att,"§") ; source=att[1] ; locale=att[2]

                if (fuzzy && toupper(from) ~ toupper(thisitem)  || ! fuzzy && from == thisitem ) 
                        printf("%s|%s|\"%s\"|\"%s\"\n", locale, source, from, to )
           }
        }
    }
    ' item="$1" fuzzy=$2 dedupe=$3
}

function getFormattedTranslations() {
    locale=$1
    # get the files, e.g tmp/Source/locales/en.json, and strip out the translation terms
    # tMatch will match the string in $T and output the best translation(s)
    if [[ "$locale" == "all" ]]; then
        for l in $(listLocales) 
        do
            for i in  $(listLocaleFiles $l) 
            do
               tFormat $i $l
            done 
        done 
    else
        for i in $(listLocaleFiles $locale) 
        do
            tFormat $i $locale
        done 
    fi
}

# print to stdout if "stdout" supplied as parameter
function mkLocaleFiles() {
    gawk 'BEGIN { FS="|"; locale="" ; out="/dev/stdout"; ct=0} {
        ct++
        if (locale == $1 ) 
            print "," >> out
        else {
            if (locale) 
                print "\n}" >> out # finish previous file
            locale = $1
                if (outputlocation != "stdout" ) # default is set in BEGIN
                    out=sprintf("%s/%s.json",outputlocation,$1)
            print "{" > out
            if (outputlocation != "stdout") 
                printf("creating %s\n",out)
        }
        printf("\t%s : %s",$3,$4) >> out;
    } END { if (ct> 0) print "\n}" >>out }' outputlocation=$1
}

function mkEnLocationFile() {
    echo $T | gawk '{ 
        ct=split($0,a,"|") 
        print "{"  
        for (i in a) {
            printf("\t\"%s\" : \"\"", a[i]) 
            if (i < ct)
                print "," 
        }
    } END { print "\n}" }
    ' 
}

function addPlaceholders() {
    tmp=$TMPDIR/$$
    for l in $(find $LOCALESDIR -type f) 
    do
        if [ $l == $ENLOCALE ]; then 
            continue
        fi
        echo |gawk 'BEGIN { print "{" ; sep="\"[[:space:]]*:" } {
            while ((getline line < localefile ) > 0)  {
                if (line ~ ":") {
                    gsub(/,[[:space:]]*$/,"",line)
                    split(line,a,sep)
                    item=a[1]
                    translation=a[2]
                    target[item]=translation
                }
            }
            ct=0
            while ((getline line < enfile ) > 0)  {
                if (line ~ ":") {
                    if (ct > 0)
                        print ","
                    ct++
                    gsub(/,[[:space:]]*$/"",line)
                    split(line,a,sep)
                    item=a[1]
                    if (target[item]) 
                        printf("%s\" : %s", item, target[item])
                    else
                        printf("%s\" : \"\"", item)
                } 
            }
        } END {print "\n}" }' enfile=$ENLOCALE localefile=$l > $tmp
        mv $tmp $l
    done
}

function coverage() {
    for l in $(find $LOCALESDIR -type f  |grep -v $ENLOCALE) 
    do
        ct=$(grep -c ":" $l)
        na=$(grep -c '""' $l)
        p=$(echo "scale=2; ( ( $ct - $na) / $ct ) * 100" |bc)
        locale=$(echo "$l" |gawk '{ print gensub(/.*\/(.*).json/,"\\1","g",$0) }')

        printf "%3.0f%% %s\n" $p $locale
    done
}

function checkOptions() {

    if [ $OPTIND -eq 0 ]; then
        usage
    fi

    if [ -z "$REPOS" ] && [ -z "$AUDIT" ] ; then
        if [ -z "$T" ] && [ -z "$EVERYTHING" ] ; then
            echo "either specify a translation string or use -e to get everything " >&2
            usage
        fi
    fi

    if [ "$REPOS" ] ; then
        if [ "$FUZZY" ] || [ "$T" ] || [ "$LOCALE" ] || [ "$MAKE" ]; then
            echo "can't use REPOS with other options" >&2
            usage 
        fi
    fi

    if [ "$T" ];then
        if [ -z "$LOCALE" ]; then
            echo "you must specify a locale (-l) when using -t" >&2
            usage
        fi
    fi

    if [ "$EVERYTHING" ]; then
        if [ "$T" ] ; then
            echo "you can't use -t and the -e everthing option together" >&2
            usage
        fi
        if [ "$LOCALE" ] ; then
            echo "the -e option extracts all available translations and can't be used with -l " >&2
            usage
        fi
        if  [ -z "$MAKE" ]; then
            echo "the -e option extracts all available translations and must be used with -m " >&2
            usage
        fi
    fi
}

#
# main
#
export TMPDIR=tmp
export LOCALESDIR=${TMPDIR}/locales
export ENLOCALE=$LOCALESDIR/en.json
export FUZZY=""
export REPOS=""
export MAKE=""
export AUDIT=""
export EVERYTHING=""
while getopts ":t:l:frmae" opt
do
    case $opt in
        t) export T="$OPTARG" ;;
        l) export LOCALE="$OPTARG" ;;
        f) FUZZY="true" ;;
        r) REPOS="true" ;;
        m) MAKE="true";;
        a) AUDIT="true";;
        e) EVERYTHING="true";;
        \?) usage ;;
    esac 
done


checkOptions

if [ ! -d "$TMPDIR" ];then
    echo "can't open $TMPDIR dir" 
    exit 1
fi

if [ "$REPOS" ] ; then
    echo "cloning repos"
    repos
    exit
fi

if [ ! "$(ls -A $TMPDIR)" ]; then
    echo "the $TMPDIR dir is empty - did you run the repos option?" >&2
    exit 1
fi

if [ "$AUDIT" ]; then
    coverage
    exit
fi

if [ "$MAKE" ]; then
    rm -rf $LOCALESDIR && mkdir -p $LOCALESDIR
    if [ "$EVERYTHING" ]; then
        echo "working - extracting all translations for all locales"
        getFormattedTranslations "all" | tMatch "all" "" "dedupe" | mkLocaleFiles $LOCALESDIR
    else
        echo "working: extracting translations for $T"
        getFormattedTranslations $LOCALE | tMatch "$T" "$FUZZY" "dedupe" | mkLocaleFiles $LOCALESDIR
        echo "making $ENLOCALE"
        mkEnLocationFile > $ENLOCALE
    fi
    echo adding placeholder entries
    addPlaceholders
    echo coverage report
    coverage
    echo "done. See $LOCALESDIR for output"
else
    echo "Working - finding translations"
    getFormattedTranslations $LOCALE | tMatch "$T" "$FUZZY" | gawk -F'|' '{ split($0,a,"/"); printf("%s/%-20s%s | %s\n", $1, a[2], $3, $4) }' |sort
    if [ "$LOCALE" != "all" ]; then
        echo "preferred translation:"
        getFormattedTranslations $LOCALE | tMatch "$T" "$FUZZY" "dedupe" | mkLocaleFiles stdout
    fi
fi
