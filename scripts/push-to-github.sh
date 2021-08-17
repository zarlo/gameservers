#!/bin/bash

source scripts/helpers.sh

# written by sappho.io

# use tmpfs
tmp="/home/server"

gl_origin="git@gitlab.com:creators_tf/gameservers/servers.git"
gh_origin="git@github.com:CreatorsTF/gameservers.git"

prebootstrap ()
{
    echo test
}

bootstrap ()
{
    if [ ! -d "${tmp}/gs" ]; then
        info "-> Cloning repo!"
        git clone ${gl_origin} \
        -b master --single-branch ${tmp}/gs \
        --depth 50 --progress --verbose --verbose --verbose
        cd ${tmp}/gs || exit 255
        info "-> moving master to gl_master"
        git checkout -b gl_master
        git branch -D master
    else
        cd ${tmp}/gs || exit 255
    fi

    if ! git remote | grep gl_origin > /dev/null; then
        info "-> adding gitlab remote"
        git remote add gl_origin ${gl_origin}
    fi

    if ! git remote | grep gh_origin > /dev/null; then
        info "-> adding github remote"
        git remote add gh_origin ${gh_origin}
    fi

    info "-> detatching"
    git switch --detach HEAD

    info "-> deleting stripped-master"
    git branch -D stripped-master

    important "-> fetching gh"

    info "-> fetching gh origin"
    git pull -X theirs gh_origin master:gh_master -f --no-edit


    #
    important "-> fetching gl"

    info "-> fetching gl origin"
    git pull -X theirs gl_origin master:gl_master -f --no-edit


    #
    important "-> fetching gl"

    info "-> deleting master"
    git branch -D gl_master

    info "-> fetching gl origin"
    git fetch gl_origin master:gl_master -f

    git checkout gh-master
    git checkout -b stripped-master
    git merge -X theirs gl_master --no-edit

    ok "bootstrapped!"
}

# used to use BFG for this
# but I didn't like the java dep and also
# git filter-repo is faster and updated more often
# -sapph
# https://github.com/newren/git-filter-repo

gfr="git filter-repo --force --preserve-commit-hashes"

bigblobs="--strip-blobs-bigger-than 100M"
sensfiles="--invert-paths --paths-from-file paths.txt --use-base-name"
senstext="--replace-text regex.txt"


stripchunkyblobs ()
{
    info "-> [gfr] stripping big blobs"

    ${gfr} ${bigblobs}

    ok "-> [gfr] stripped big blobs"
}

movebinaries ()
{
    echo a
    # temporarily rid of files that we don't give a shit abt
    #find . -type f -name "*.bsp" -exec rm -fv {} +;
    #find . -type f -name "*.so"  -exec rm -fv {} +;
    #find . -type f -name "*.dll" -exec rm -fv {} +;
    #find . -type f -name "*.smx" -exec rm -fv {} +;
}

stripfiles ()
{
    info "-> [gfr] stripping sensitive files"

    true > paths.txt
    # echo our regex && literal paths to it
    {
        echo 'regex:private.*';
        echo 'regex:databases.*';
        echo 'regex:economy.*';
        echo 'discord.cfg';
        echo 'discord_seed.sp';
    } >> paths.txt

    # invert-paths deletes these files
    ${gfr} ${sensfiles}
    rm paths.txt

    ok "-> [gfr] stripped sensitive files"
}

stripsecrets ()
{
    # strip sensitive strings
    #
    info "-> [gfr] stripping sensitive strings"

    true > regex.txt
    # echo our regex to it
    # i want to simplify this
    {
// ***REPLACED SRC PASSWORD***
        echo 'regex:(?m)(***REPLACED C.TF API INFO***>***REPLACED C.TF API INFO***';
        echo 'regex:(?m)(\bhttp.*(@|/api/webhook).*\b)==>***REPLACED PRIVATE URL***';
    } >> regex.txt

    ${gfr} ${senstext}
    rm regex.txt

    ok "-> [gfr] stripped sensitive strings"
}

push ()
{
    # donezo
    ok "-> pushing to gh"
    git push gh_origin stripped-master:master --progress --verbose --verbose --verbose
}

bootstrap
stripchunkyblobs
stripfiles
stripsecrets
sync
push
