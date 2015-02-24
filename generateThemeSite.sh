#!/bin/bash

# This is the hugo Theme Site Builder
mkdir -p hugoThemeSite
cd hugoThemeSite

#hugo new site themes

git clone https://github.com/spf13/HugoThemesSite.git themeSite
git clone https://github.com/spf13/HugoBasicExample.git exampleSite
cd exampleSite
git clone --recursive https://github.com/spf13/hugoThemes.git themes
cd ..

mkdir -p themeSite/content
mkdir -p themeSite/static/images

for x in `ls -d exampleSite/themes/*/ | cut -d / -f3`; do
    echo hugo -s exampleSite -d ../themeSite/static/theme/$x/ -t $x -b http://themes.gohugo.io/theme/$x/
    hugo -s exampleSite -d ../themeSite/static/theme/$x/ -t $x -b http://themes.gohugo.io/theme/$x/

    echo "+++" > themeSite/content/$x.md
    echo "screenshot = \"/images/$x.screenshot.png\"" >> themeSite/content/$x.md
    echo "thumbnail = \"/images/$x.tn.png\"" >> themeSite/content/$x.md
    echo "demo = \"/theme/$x/\"" >> themeSite/content/$x.md
    repo=`git -C exampleSite/themes/$x remote -v | head -n 1 | awk '{print$2}'`
    echo "source = \"$repo\"" >> themeSite/content/$x.md
    cat exampleSite/themes/$x/theme.toml >> themeSite/content/$x.md
    echo -en "+++\n" >> themeSite/content/$x.md

    cat exampleSite/themes/$x/README.md >> themeSite/content/$x.md

    cp exampleSite/themes/$x/images/screenshot.png themeSite/static/images/$x.screenshot.png
    cp exampleSite/themes/$x/images/tn.png themeSite/static/images/$x.tn.png
done

echo -en "**********************************************************************\n"
echo -en "\n"
echo -en "to view the site locally run 'hugo server -s hugoThemeSite/themeSite'\n"
echo -en "\n"
echo -en "**********************************************************************\n"
