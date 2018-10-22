#!/bin/bash
# Custom bash prompt
# Usage: add `source set_prompt.sh` to your .bashrc

PS1_CONFIG_FILE="${HOME}/.config/ps1"

__ps1_create_config()
{
    echo '#!/bin/bash'
    echo
    echo '# Settings: 0 or 1'
    echo 'export PS1_DEBUG=0'
    echo 'export PS1_USE_16M_COLOR=1'
    echo
    echo '# lowercase: decimal'
    echo '# uppercase: hexadecimal'
    echo '# rrr;ggg;bbb or #RGB or #RRGGBB or $VARIABLE'
    echo 'export COLOR_PREFIX="#fc0"'
    echo 'export COLOR_USER="#0c6"'
    echo 'export COLOR_HOST=$COLOR_USER'
    echo 'export COLOR_CWD="#077"'
    echo 'export COLOR_REPO="#0ff"'
    echo '# No changes to commit'
    echo 'export COLOR_BRANCH_CLEAN="#0f0"'
    echo '# All changes are staged'
    echo 'export COLOR_BRANCH_STAGED="#ff0"'
    echo '# Any modified or new files that are not staged'
    echo 'export COLOR_BRANCH_DIRTY="#f00"'
    echo '# Used for '$' at end of prompt'
    echo 'export COLOR_END="#fff"'
    echo
    echo 'export BOLD_USER=1'
    echo 'export BOLD_HOST=1'
    echo 'export BOLD_CWD=0'
    echo 'export BOLD_REPO=0'
    echo 'export BOLD_BRANCH=0'
    echo 'export BOLD_END=0'
}

if [ ! -f "$PS1_CONFIG_FILE" ]; then
    __ps1_create_config > "$PS1_CONFIG_FILE"
fi
source "$PS1_CONFIG_FILE"

__ps1_dbg()
{
    if [ $PS1_DEBUG -eq 1 ]; then
        >&2 echo $@
    fi
}

__ps1_dec2hex()
{
    echo "obase=16; $1" | bc
}

__ps1_octal_digit()
{
    x=$1
    y=7
    printf '%d' "$(( x>7?7:x ))"
}

__ps1_color_from_hex(){
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
    if [ $PS1_USE_16M_COLOR -eq 0 ]; then
        index="$(( (r<75?0:(r-35)/40)*36 + 
                (g<75?0:(g-35)/40)*6   +
                (b<75?0:(b-35)/40)     + 16 ))"
        index=$(
            for (( i=0; i<${#index}; i++)); do __ps1_octal_digit ${index:$i:1}; done
        )
    else
        index=$(printf "%03d;%03d;%03d" $r $g $b)
    fi
    __ps1_dbg "#$hex->$index"
    echo $index
}

__ps1_reset_fmt(){
    printf '\[\e[0m\]'
}

__ps1_bold()
{
    printf "%s%s%s" '\[\e[1m\]' $1 $(__ps1_reset_fmt)
}

__ps1_color_start()
{
    case "$1" in
        "#"*) COLOR=$(__ps1_color_from_hex "$1");;
        *";"*";"*)  COLOR="$1"::
    esac
    if [ $PS1_USE_16M_COLOR -eq 0 ]; then
        printf '\[\e[38;5;%dm\]' "$COLOR"
    else
        printf '\[\e[038;2;%sm\]' "$COLOR"
    fi
}

__ps1_color(){
    COLOR="$(__ps1_color_start "$1")"
    TEXT=$2
    if [ $PS1_USE_16M_COLOR -eq 0 ]; then
        printf '%s%s%s' $COLOR "$TEXT" $(__ps1_reset_fmt)
    else
        printf '%s%s%s' $COLOR "$TEXT" $(__ps1_reset_fmt)
    fi
}

__ps1_git_repo()
{
    REPO=$(git config --get remote.origin.url || git rev-parse --show-toplevel 2> /dev/null)
    if [ $? -eq 0 ]; then
        printf "$(basename ${REPO%.git})"
    fi
}

__ps1_git_branch()
{
    REPO="$(__ps1_git_repo)"
    BRANCH="$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')"
    if [[ "$REPO" ]]; then
        REPO="$(__ps1_color $COLOR_REPO $REPO)"
        if [ $BOLD_REPO -eq 1 ]; then
            REPO="$(__ps1_bold $REPO)"
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

__ps1_git_info()
{
    REPO="$(__ps1_git_repo)"
    BRANCH="$(__ps1_git_branch)"
    if [[ "$BRANCH" ]]; then
        REPO="$(__ps1_color $COLOR_REPO $REPO)"
        if [ $BOLD_REPO -eq 1 ]; then
            REPO="$(__ps1_bold $REPO)"
        fi
        if git status | grep -E 'Changes not staged|Untracked files|Unmerged paths' > /dev/null; then
            BRANCH="$(__ps1_color $COLOR_BRANCH_DIRTY "$BRANCH*")"
        elif git status | grep 'Changes to be committed' > /dev/null; then
            BRANCH=$(__ps1_color $COLOR_BRANCH_STAGED "$BRANCH*")
        else
            BRANCH="$(__ps1_color $COLOR_BRANCH_CLEAN $BRANCH)"
        fi
        if [ $BOLD_BRANCH -eq 1 ]; then
            GIT_INFO+="$(__ps1_bold $BRANCH)"
        fi
        echo "($REPO: $BRANCH)\n"
    fi
}

__ps1_join_by()
{
    local IFS="$1"
    shift
    echo "$*"
}

__ps1_trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

__ps1_build_prefix()
{
    pref=()
    if [ ! -z "${VIRTUAL_ENV+x}" ]; then
        pref+=("$(basename "$VIRTUAL_ENV")")
    fi
    if [ ! -z "${VIRTUAL_ENV_TOOLS+x}" ]; then
        pref+=("${ENV_NAME_TOOLS}-tools")
    fi
    pref="$(__ps1_trim "$(__ps1_join_by '; ' ${pref[@]})")"
    echo "${pref}"
}

__ps1_set()
{
    PS1=""
    PS1_PREFIX="$(__ps1_build_prefix)"
    # if [ ! -z "${PS1_PREFIX+x}" ]; then
    if [ ! -z "${PS1_PREFIX}" ]; then
        PS1_PREFIX="(${PS1_PREFIX})"
        PS1+="$(__ps1_color $COLOR_PREFIX "$PS1_PREFIX ")"
    fi

    git_info="$(__ps1_git_info)"
    if [ ! -z "$git_info" ]; then
        if [ ! -z "$PS1" ]; then
            PS1+=' '
        fi
        PS1+="$git_info"
    fi

    PS1+="${debian_chroot:+($debian_chroot)}"
    if [ $BOLD_USER -eq 1 ]; then
        PS1+="$(__ps1_bold $(__ps1_color $COLOR_USER \\u))"
    else
        PS1+="$(__ps1_color $COLOR_USER \\u)"
    fi
    PS1+="@"
    if [ $BOLD_HOST -eq 1 ]; then
        PS1+="$(__ps1_bold $(__ps1_color $COLOR_HOST \\h))"
    else
        PS1+="$(__ps1_color $COLOR_HOST \\h)"
    fi
    PS1+=":"
    if [ $BOLD_CWD -eq 1 ]; then
        PS1+="$(__ps1_bold $(__ps1_color $COLOR_CWD \\w))"
    else
        PS1+="$(__ps1_color $COLOR_CWD \\w)"
    fi
    if [ $BOLD_END -eq 1 ]; then
        PS1+="$(__ps1_bold $(__ps1_color $COLOR_END \\$))"
    else
        PS1+="$(__ps1_color $COLOR_END \\$)"
    fi
    PS1+=" "

    export PS1
}

if [[ ! "$PROMPT_COMMAND" = *"__ps1_set"* ]]; then
    PROMPT_COMMAND+='__ps1_set;'
fi
