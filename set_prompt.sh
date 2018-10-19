#!/bin/bash
# Custom bash prompt
# Usage: add `source set_prompt.sh` to your .bashrc

# Settings: 0 or 1
DEBUG=0
USE_16M_COLOR=1

# lowercase: decimal
# uppercase: hexadecimal
# rrr;ggg;bbb or #RGB or #RRGGBB or $VARIABLE
COLOR_PREFIX="#fc0"
COLOR_USER="#0c6"
COLOR_HOST=$COLOR_USER
COLOR_CWD="#077"
COLOR_REPO="#0ff"
# No changes to commit
COLOR_BRANCH_CLEAN="#0f0"
# All changes are staged
COLOR_BRANCH_STAGED="#ff0"
# Any modified or new files that are not staged
COLOR_BRANCH_DIRTY="#f00"
# Used for '$' at end of prompt
COLOR_END="#fff"

BOLD_USER=1
BOLD_HOST=1
BOLD_CWD=0
BOLD_REPO=0
BOLD_BRANCH=0
BOLD_END=0

unset PS1_SUFFIX

dbg()
{
    if [ $DEBUG -eq 1 ]; then
        >&2 echo $@
    fi
}

dec2hex()
{
    echo "obase=16; $1" | bc
}

octal_digit()
{
    x=$1
    y=7
    printf '%d' "$(( x>7?7:x ))"
}

color_from_hex(){
    hex=${1#"#"}
    if [[ ( "${#hex}" == 3 ) ]]; then
        r=$(printf '0x%0.1s%0.1s' ${hex} ${hex})
        g=$(printf '0x%0.1s%0.1s' ${hex#?} ${hex#?})
        b=$(printf '0x%0.1s%0.1s' ${hex#??} ${hex#??})
    else
        r=$(printf '0x%0.2s' "$hex")
        g=$(printf '0x%0.2s' ${hex#??})
        b=$(printf '0x%0.2s' ${hex#????})
    fi
    if [ $USE_16M_COLOR -eq 0 ]; then
        index="$(( (r<75?0:(r-35)/40)*36 + 
                (g<75?0:(g-35)/40)*6   +
                (b<75?0:(b-35)/40)     + 16 ))"
        index=$(
            for (( i=0; i<${#index}; i++)); do octal_digit ${index:$i:1}; done
        )
    else
        index=$(printf "%03d;%03d;%03d" $r $g $b)
    fi
    dbg "#$hex->$index"
    echo $index
}

reset_fmt(){
    printf '\[\e[0m\]'
}

bold()
{
    printf "%s%s%s" '\[\e[1m\]' $1 $(reset_fmt)
}

color(){
    case "$1" in
        "#"*) COLOR=$(color_from_hex $1);;
        *";"*";"*)  COLOR=$1::
    esac
    TEXT=$2
    if [ $USE_16M_COLOR -eq 0 ]; then
        printf '\[\e[38;5;%dm\]%s%s' $COLOR "$TEXT" $(reset_fmt)
    else
        printf '\[\e[038;2;%sm\]%s%s' $COLOR "$TEXT" $(reset_fmt)
    fi
}

git_repo()
{
    REPO=$(git config --get remote.origin.url || git rev-parse --show-toplevel 2> /dev/null)
    if [ $? -eq 0 ]; then
        printf "$(basename ${REPO%.git})"
    fi
}

git_branch()
{
    REPO="$(git_repo)"
    BRANCH="$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')"
    if [[ "$REPO" ]]; then
        REPO="$(color $COLOR_REPO $REPO)"
        if [ $BOLD_REPO -eq 1 ]; then
            REPO="$(bold $REPO)"
        fi
        if [ -z "$BRANCH" ]; then
            BRANCH="$(git status 2> /dev/null | grep -oP '(?<=On branch ).*')"
        else
            BRANCH="${BRANCH//\(}"
            BRANCH="${BRANCH//\)}"
        fi
        printf "$BRANCH"
    fi
}

parse_git_info()
{
    REPO="$(git_repo)"
    BRANCH="$(git_branch)"
    if [[ "$BRANCH" ]]; then
        REPO="$(color $COLOR_REPO $REPO)"
        if [ $BOLD_REPO -eq 1 ]; then
            REPO="$(bold $REPO)"
        fi
        if git status | grep -E 'Changes not staged|Untracked files|Unmerged paths' > /dev/null; then
            BRANCH="$(color $COLOR_BRANCH_DIRTY "$BRANCH*")"
        elif git status | grep 'Changes to be committed' > /dev/null; then
            BRANCH=$(color $COLOR_BRANCH_STAGED "$BRANCH*")
        else
            BRANCH="$(color $COLOR_BRANCH_CLEAN $BRANCH)"
        fi
        if [ $BOLD_BRANCH -eq 1 ]; then
            GIT_INFO+="$(bold $BRANCH)"
        fi
        echo "($REPO: $BRANCH)\n"
    fi
}

join_by()
{
    local IFS="$1"
    shift
    echo "$*"
}

trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

build_prefix()
{
    pref=()
    if [ ! -z "${VIRTUAL_ENV+x}" ]; then
        pref+=("$(basename "$VIRTUAL_ENV")")
    fi
    if [ ! -z "${VIRTUAL_ENV_TOOLS+x}" ]; then
        pref+=("${ENV_NAME_TOOLS}-tools")
    fi
    pref="$(trim "$(join_by '; ' ${pref[@]})")"
    echo "${pref}"
}

set_ps1()
{
    PS1=""
    PS1_PREFIX="$(build_prefix)"
    # if [ ! -z "${PS1_PREFIX+x}" ]; then
    if [ ! -z "${PS1_PREFIX}" ]; then
        PS1_PREFIX="(${PS1_PREFIX})"
        PS1+="$(color $COLOR_PREFIX "$PS1_PREFIX ")"
    fi

    git_info="$(parse_git_info)"
    if [ ! -z "$git_info" ]; then
        if [ ! -z "$PS1" ]; then
            PS1+=' '
        fi
        PS1+="$git_info"
    fi

    PS1+="${debian_chroot:+($debian_chroot)}"
    if [ $BOLD_USER -eq 1 ]; then
        PS1+="$(bold $(color $COLOR_USER \\u))"
    else
        PS1+="$(color $COLOR_USER \\u)"
    fi
    PS1+="@"
    if [ $BOLD_HOST -eq 1 ]; then
        PS1+="$(bold $(color $COLOR_HOST \\h))"
    else
        PS1+="$(color $COLOR_HOST \\h)"
    fi
    PS1+=":"
    if [ $BOLD_CWD -eq 1 ]; then
        PS1+="$(bold $(color $COLOR_CWD \\w))"
    else
        PS1+="$(color $COLOR_CWD \\w)"
    fi
    if [ $BOLD_END -eq 1 ]; then
        PS1+="$(bold $(color $COLOR_END \\$))"
    else
        PS1+="$(color $COLOR_END \\$)"
    fi
    PS1+=" "

    export PS1
    export PS1_SUFFIX=${PS1//$PS1_PREFIX /}
}

if [[ ! "$PROMPT_COMMAND" = *"set_ps1"* ]]; then
    PROMPT_COMMAND+='set_ps1;'
fi
