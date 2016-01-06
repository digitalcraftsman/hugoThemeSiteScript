#!/bin/bash

function try {
  "$@"
  code=$?
  if [ $code -ne 0 ]
  then
    echo "$1 failed: exit status $code"
    exit 1
  fi
}

function fixReadme {
  local content=$(cat $1)
  # Make images viewable outside GitHub
  content=$( echo "$content" | perl -p -e 's/github\.com\/(.*?)\/blob\/master\/images/raw\.githubusercontent\.com\/$1\/master\/images/g;' )
  # Tell Hugo not to process shortcode samples
  content=$( echo "$content" | perl -p -e 's/{{%(.*?)%}}/{{%\/*$1*\/%}}/g;' )
  content=$( echo "$content" | perl -p -e 's/{{<(.*?)>}}/{{<\/*$1*\/>}}/g;' )
  
  echo "$content"
}

# Silent pushd
pushd () {
    command pushd "$@" > /dev/null
}

# Silent popd
popd () {
    command popd "$@" > /dev/null
}

# Load the repositories from the provided environment variables or our defaults
HUGO_THEME_SITE_REPO=${HUGO_THEME_SITE_REPO:-https://github.com/spf13/HugoThemesSite.git}
HUGO_BASIC_EXAMPLE_REPO=${HUGO_BASIC_EXAMPLE_REPO:-https://github.com/spf13/HugoBasicExample.git}
HUGO_THEMES_REPO=${HUGO_THEMES_REPO:-https://github.com/spf13/hugoThemes.git}

echo "Using ${HUGO_THEMES_REPO} for themes"
echo "Using ${HUGO_THEME_SITE_REPO} for theme site"
echo "Using ${HUGO_BASIC_EXAMPLE_REPO} for example site"

GLOBIGNORE=.*
siteDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/hugoThemeSite"

configTplPrefix="config-tpl"
configBase="${configTplPrefix}-base"
configBaseParams="${configTplPrefix}-params"

# This is the hugo Theme Site Builder
mkdir -p hugoThemeSite

pushd hugoThemeSite

if [ -d themeSite ]; then
  pushd themeSite
  git pull --rebase
  popd
else
  git clone ${HUGO_THEME_SITE_REPO} themeSite
fi

if [ -d exampleSite ]; then
  pushd exampleSite
  git pull --rebase
  popd
else
  git clone ${HUGO_BASIC_EXAMPLE_REPO} exampleSite
fi

pushd exampleSite

if [ -d themes ]; then
  pushd themes
  git pull --rebase
  git submodule update --init --recursive
  popd
else
  git clone --recursive ${HUGO_THEMES_REPO} themes
fi

popd

# Clean before new build
try rm -rf themeSite/public
try rm -rf themeSite/static/theme
try rm -rf themeSite/content
try rm -rf themeSite/static/images

mkdir -p themeSite/content
mkdir -p themeSite/static/images

if [ $# -eq 1 ]; then
  BASEURL="$1"
else
  BASEURL="http://themes.gohugo.io"
fi

# persona: https://github.com/pcdummy/hugo-theme-persona/issues/1
# html5: https://github.com/simonmika/hugo-theme-html5/issues/2
blacklist=('persona', 'html5', '.git')

# hugo-incorporated: too complicated, needs its own
# exampleSite: https://github.com/nilproductions/hugo-incorporated/issues/24
# still using deprecated vars (0.14): 'aglaus'
# Journal: broken layout: TODO make issue
# cocoa: exampleSite isn't neutral (see the about page)
# github-project-landing-page missing static folder
# https://github.com/oarrabi/github-project-landing-page/issues/1
noDemo=('hugo-incorporated', 'aglaus', 'journal', 'cocoa', 'github-project-landing-page')

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

  echo " ==== PROCESSING " $x " ====== "
  
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
  echo -en "\n+++\n\n" >> themeSite/content/$x.md
  
  fixReadme exampleSite/themes/$x/README.md >> themeSite/content/$x.md
  
  if ! $generateDemo; then
    continue
  fi
  
  if [ -d "exampleSite/themes/$x/exampleSite" ]; then
    # Use content and config in exampleSite
    echo "Building site for theme ${x} using its own exampleSite"
	
	# Hugo should exit with an error code on these ...
	if [ ! -d "exampleSite/themes/$x/exampleSite/content" ]; then
		echo "Example site for theme ${x} missing /content folder"
		exit 1
	fi
	if [ ! -d "exampleSite/themes/$x/exampleSite/static" ]; then
		echo "Example site for theme ${x} missing /static folder"
		exit 1
	fi
    
    ln -s ${siteDir}/exampleSite/themes/$x/exampleSite ${siteDir}/exampleSite2
    ln -s ${siteDir}/exampleSite/themes ${siteDir}/exampleSite2/themes
    try hugo -s exampleSite2 -d ../themeSite/static/theme/$x/  --canonifyURLs=true -t $x -b $BASEURL/theme/$x/
    rm ${siteDir}/exampleSite2/themes
    rm ${siteDir}/exampleSite2
    
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
  try hugo -s exampleSite --config=${themeConfig} --canonifyURLs=true -d ../themeSite/static/theme/$x/ -t $x -b $BASEURL/theme/$x/
  
done

unset GLOBIGNORE

echo -en "**********************************************************************\n"
echo -en "\n"
echo -en "to view the site locally run 'hugo server -s hugoThemeSite/themeSite'\n"
echo -en "\n"
echo -en "**********************************************************************\n"
