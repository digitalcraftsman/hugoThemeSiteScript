#!/bin/bash

function try {
    "$@"
    code=$?
    if [ $code -ne 0 ]
    then
        echo "$1 failed: exit status $code"
		# Uncomment below to fail fast
       # exit 1 
    fi
}

function fixReadme {
	local content=$(cat $1)
	content=$( echo "$content" | perl -p -e 's/github\.com\/(.*?)\/blob\/master\/images/raw\.githubusercontent\.com\/$1\/master\/images/g;' )	
	echo "$content"
}

GLOBIGNORE=.*
siteDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/hugoThemeSite"

configTplPrefix="config-tpl"
configBase="${configTplPrefix}-base"
configBaseParams="${configTplPrefix}-params"

# This is the hugo Theme Site Builder
mkdir -p hugoThemeSite
cd hugoThemeSite

if [ -d themeSite ]; then
	cd themeSite
	git pull --rebase
	cd ..
else
	git clone https://github.com/spf13/HugoThemesSite.git themeSite  
fi
if [ -d exampleSite ]; then
	cd exampleSite
	git pull --rebase
	cd ..
else
	git clone https://github.com/spf13/HugoBasicExample.git exampleSite
fi

cd exampleSite

if [ -d themes ]; then
	cd themes
	git pull --rebase
	git submodule update --init --recursive
	cd ..
else
	git clone --recursive https://github.com/spf13/hugoThemes.git themes
fi

cd ..

# clean before new build
try rm -rf themeSite/public
try rm -rf themeSite/static/theme
try rm -rf themeSite/content
try rm -rf themeSite/static/images

mkdir -p themeSite/content
mkdir -p themeSite/static/images

if [ $# -eq 1 ]; then
    BASEURL="$1"
else
    BASURL="http://themes.gohugo.io"
fi

# persona: https://github.com/pcdummy/hugo-theme-persona/issues/1
# html5: https://github.com/simonmika/hugo-theme-html5/issues/2
blacklist=('persona', 'html5')

# hugo-incorporated: too complicated, needs its own exampleSite: https://github.com/nilproductions/hugo-incorporated/issues/24
# landing-page-hugo: same as above
noDemo=('hugo-incorporated', 'landing-page-hugo')


for x in `ls -d exampleSite/themes/*/ | cut -d / -f3`; do
	blacklisted=`echo ${blacklist[*]} | grep "$x"`
	if [ "${blacklisted}" != "" ]; then
		continue
	fi
	
	generateDemo=true
	inNoDemo=`echo ${noDemo[*]} | grep "$x"`
	if [ "${inNoDemo}" != "" ]; then
		generateDemo=false
	fi
	
    cp exampleSite/themes/$x/images/screenshot.png themeSite/static/images/$x.screenshot.png
    cp exampleSite/themes/$x/images/tn.png themeSite/static/images/$x.tn.png
	
    echo "+++" > themeSite/content/$x.md
    echo "screenshot = \"/images/$x.screenshot.png\"" >> themeSite/content/$x.md
    echo "thumbnail = \"/images/$x.tn.png\"" >> themeSite/content/$x.md
	if $generateDemo; then
	    echo "demo = \"/theme/$x/\"" >> themeSite/content/$x.md
	fi
    repo=`git -C exampleSite/themes/$x remote -v | head -n 1 | awk '{print$2}'`
    echo "source = \"$repo\"" >> themeSite/content/$x.md
    cat exampleSite/themes/$x/theme.toml >> themeSite/content/$x.md
    echo -en "+++\n" >> themeSite/content/$x.md

    fixReadme exampleSite/themes/$x/README.md >> themeSite/content/$x.md
	
	
	
	if [ -d "exampleSite/themes/$x/exampleSite" ]; then
		# Use content and config in exampleSite
	    echo "Building site for theme ${x} using its own exampleSite"
		
		ln -s ${siteDir}/exampleSite/themes/$x/exampleSite ${siteDir}/exampleSite2
		ln -s ${siteDir}/exampleSite/themes ${siteDir}/exampleSite2/themes  
	    try hugo -v -s exampleSite2 -d ../themeSite/static/theme/$x/ -t $x -b $BASEURL/theme/$x/
		rm ${siteDir}/exampleSite2/themes
		rm ${siteDir}/exampleSite2
	
		continue
	fi	
	
	if ! $generateDemo; then
		continue
	fi
	
	themeConfig="${TMPDIR}config-${x}.toml"
	baseConfig="${configBase}.toml"
	paramsConfig="${configBaseParams}.toml"
	
	
	if [ -f "themeSite/templates/${configBase}-${x}.toml" ]; then
		baseConfig="${configBase}-${x}.toml"		
	fi
	
	if [ -f "themeSite/templates/${configBaseParams}-${x}.toml" ]; then
		paramsConfig="${configBaseParams}-${x}.toml"		
	fi
	
	cat themeSite/templates/${baseConfig} > ${themeConfig}
	cat themeSite/templates/${paramsConfig} >> ${themeConfig}
	
    echo "Building site for theme ${x} using config ${themeConfig}"
    try hugo -s exampleSite --config=${themeConfig} -d ../themeSite/static/theme/$x/ -t $x -b $BASEURL/theme/$x/

done

unset GLOBIGNORE


echo -en "**********************************************************************\n"
echo -en "\n"
echo -en "to view the site locally run 'hugo server -s hugoThemeSite/themeSite'\n"
echo -en "\n"
echo -en "**********************************************************************\n"
