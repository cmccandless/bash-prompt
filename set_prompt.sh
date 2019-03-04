#!/bin/bash
# Custom bash prompt
# Usage: add `source set_prompt.sh` to your .bashrc

PS1_CONFIG_FILE="${HOME}/.config/ps1"

_PS1_RESET='\e[0m'
_PS1_BOLD='\e[1m'

__ps1_create_config()
{
    echo '#!/bin/bash'
    echo
    echo '# Settings: 0 or 1'
    echo 'export PS1_DEBUG=0'
    echo 'export PS1_USE_16M_COLOR=1'
    echo 'export SHOW_GIT_INFO=1'
    echo 'export SHOW_LAST_RESULT=0'
    echo
    echo 'export SYMBOL_SUCCESS="✔️"'
    echo 'export SYMBOL_FAIL="❌"'
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
    echo 'export COLOR_SUCCESS="#0f0"'
    echo 'export COLOR_FAIL="#f00"'
    echo
    echo 'export BOLD_USER=1'
    echo 'export BOLD_HOST=1'
    echo 'export BOLD_CWD=0'
    echo 'export BOLD_REPO=0'
    echo 'export BOLD_BRANCH=0'
    echo 'export BOLD_END=0'
    echo 'export BOLD_LAST_RESULT=0'
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

__ps1_color()
{
    case "$1" in
        "#"*) COLOR=$(__ps1_color_from_hex "$1");;
        *";"*";"*)  COLOR="$1"::
    esac
    if [ $PS1_USE_16M_COLOR -eq 0 ]; then
        printf '\e[38;5;%dm' "$COLOR"
    else
        printf '\e[038;2;%sm' "$COLOR"
    fi
}

__ps1_git_repo()
{
    REPO=$((git config --get remote.origin.url || git rev-parse --show-toplevel) 2> /dev/null)
    if [ $? -eq 0 ]; then
        printf "$(basename ${REPO%%.git})"
    else
        return 1
    fi
}

__ps1_git_branch()
{
    status="$1"
    # REPO="$(__ps1_git_repo)"
    if __ps1_git_repo &> /dev/null; then
        BRANCH="$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
        if [ "$BRANCH" == 'HEAD' ]; then
            BRANCH="HEAD detached at $(git rev-parse --short HEAD 2> /dev/null)"
            if [ "$?" -ne 0 ]; then
                BRANCH='EMPTY REPOSITORY'
            fi
        else
            BRANCH="${BRANCH//\(}"
            BRANCH="${BRANCH//\)}"
        fi
        printf "$BRANCH"
    else
        return 1
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

__ps1_strip_prefix()
{
    if [ ! -z "${VIRTUAL_ENV+x}" ]; then
        export PS1="${PS1//"($(basename $VIRTUAL_ENV)) "}"
    fi
    if [ ! -z "${VIRTUAL_ENV_TOOLS+x}" ]; then
        export PS1="${PS1//"(${ENV_NAME_TOOLS} tools) "}"
    fi
}

__ps1_prefix()
{
    pref=()
    if [ -n "${VIRTUAL_ENV+x}" ]; then
        pref+=("$(basename "$VIRTUAL_ENV")")
    fi
    if [ -n "${VIRTUAL_ENV_TOOLS+x}" ] && [ -n "${ENV_NAME_TOOLS}" ]; then
        pref+=("${ENV_NAME_TOOLS}-tools")
    fi
    if [[ "${#pref}" == 0 ]]; then
        return 1
    fi
    pref="$(__ps1_trim "$(__ps1_join_by '; ' ${pref[@]})")"
    printf "($pref) "
    return 0
}

__ps1_bold()
{
    [[ $1 == 1 ]] && printf "$_PS1_BOLD"
}

git_dirty()
{
    ! git diff-files --no-ext-diff --quiet 2> /dev/null ||
    [ -n "$(git ls-files --others --exclude-standard --directory --no-empty-directory --error-unmatch -- ':/*' 2> /dev/null)" ]
}

git_staged()
{
    ! git diff-index --no-ext-diff --quiet --cached HEAD 2> /dev/null
}

set_prompt()
{
    # Pre-render colors
    colorPrefix="$(__ps1_color $COLOR_PREFIX)"
    boldPrefix="$(__ps1_bold $BOLD_PREFIX)"

    colorRepo="$(__ps1_color $COLOR_REPO)"
    boldRepo="$(__ps1_bold $BOLD_REPO)"

    colorBranchDirty="$(__ps1_color $COLOR_BRANCH_DIRTY)"
    colorBranchStaged="$(__ps1_color $COLOR_BRANCH_STAGED)"
    colorBranchClean="$(__ps1_color $COLOR_BRANCH_CLEAN)"
    boldBranch="$(__ps1_bold $BOLD_BRANCH)"

    colorSuccess="$(__ps1_color $COLOR_SUCCESS)"
    colorFail="$(__ps1_color $COLOR_FAIL)"
    boldLastResult="$(__ps1_bold $BOLD_LAST_RESULT)"

    colorUser="$(__ps1_color $COLOR_USER)"
    boldUser="$(__ps1_bold $BOLD_USER)"
    colorHost="$(__ps1_color $COLOR_HOST)"
    boldHost="$(__ps1_bold $BOLD_HOST)"
    colorCwd="$(__ps1_color $COLOR_CWD)"
    boldCwd="$(__ps1_bold $BOLD_CWD)"
    colorEnd="$(__ps1_color $COLOR_END)"
    boldEnd="$(__ps1_bold $BOLD_END)"

    PS1='$('
    PS1+='ret=$?;'
    PS1+='prefix="$(__ps1_prefix)";'
    PS1+='if [[ $? == 0 ]]; then '
    PS1+='printf "\[${boldPrefix}${colorPrefix}\]$prefix\[$_PS1_RESET\]";'
    PS1+='fi;'
    if [[ $SHOW_GIT_INFO == 1 ]]; then
        PS1+='if git rev-parse --is-inside-work-tree &> /dev/null; then '
        PS1+='printf "(";'
        PS1+='printf "\[${boldRepo}${colorRepo}\]$(__ps1_git_repo)\[$_PS1_RESET\]: ";'
        PS1+='printf "\[${boldBranch}";'
        PS1+='if git_dirty; then '
        PS1+='printf "${colorBranchDirty}";'
        PS1+='elif git_staged; then ';
        PS1+='printf "${colorBranchStaged}";'
        PS1+='else ';
        PS1+='printf "${colorBranchClean}";'
        PS1+='fi;'
        PS1+='printf "\]$(__ps1_git_branch)\[$_PS1_RESET\])";'
        PS1+='printf "\n";'
        PS1+='fi;'
    fi
    if [ "$SHOW_LAST_RESULT" -eq 1 ]; then
        PS1+='printf "\[${boldLastResult}";'
        PS1+='if [[ $ret == 0 ]]; then '
        PS1+='printf "${colorSuccess}\]$SYMBOL_SUCCESS";'
        PS1+='else '
        PS1+='printf "${colorFail}\]$SYMBOL_FAIL";'
        PS1+='fi;'
        PS1+='printf "\[$_PS1_RESET\] ";'
    fi
    PS1+=")"
    PS1+="${debian_chroot:+($debian_chroot)}"
    PS1+="\[${boldUser}${colorUser}\]\\u\[$_PS1_RESET\]@"
    PS1+="\[${boldHost}${colorHost}\]\\h\[$_PS1_RESET\]:"
    PS1+="\[${boldCwd}${colorCwd}\]\\w\[$_PS1_RESET\]"
    PS1+="\[${boldEnd}${colorEnd}\]\\$\[$_PS1_RESET\] "
    export PS1
}

set_prompt
PROMPT_COMMAND='__ps1_strip_prefix'
