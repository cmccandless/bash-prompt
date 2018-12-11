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
    if [ ! -z "$1" ]; then
        printf "%s%s%s" '\[\e[1m\]' $1 $(__ps1_reset_fmt)
    fi
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
    TEXT=$2
    if [ -z "$TEXT" ]; then
        return
    fi
    if [ -z "$1" ]; then
        echo "$TEXT"
        return
    fi
    COLOR="$(__ps1_color_start "$1")"
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

__ps1_sub()
{
    PLACEHOLDER="$1"
    SUB="$2"
    echo "$PLACEHOLDER" | sed s'/%%/'"$SUB"'/'
}

__ps1_git_info()
{
    REPO="$(__ps1_git_repo)"
    BRANCH="$(__ps1_git_branch)"
    if [[ "$BRANCH" ]]; then
        REPO="$(__ps1_sub "$_PS1_PLACEHOLDER_GIT_REPO" "$REPO")"
        if git status | grep -E 'Changes not staged|Untracked files|Unmerged paths' > /dev/null; then
            BRANCH="$(__ps1_sub "$_PS1_PLACEHOLDER_GIT_BRANCH_DIRTY" "$BRANCH")"
        elif git status | grep 'Changes to be committed' > /dev/null; then
            BRANCH="$(__ps1_sub "$_PS1_PLACEHOLDER_GIT_BRANCH_STAGED" "$BRANCH")"
        else
            BRANCH="$(__ps1_sub "$_PS1_PLACEHOLDER_GIT_BRANCH_CLEAN" "$BRANCH")"
        fi
        echo "($REPO: $BRANCH)"
        return 0
    fi
    return 1
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

__ps1_prefix()
{
    pref="$(__ps1_build_prefix)"
    if [ -z "$pref" ]; then
        return 1
    fi
    printf "$(__ps1_sub "$_PS1_PLACEHOLDER_PREFIX" "($pref)") "
    return 0
}

render()
{
    TEXT="$1"
    COLOR="$2"
    BOLD="${3:-0}"
    local ph
    ph="$(__ps1_color $COLOR "$TEXT")"
    if [ $BOLD -eq 1 ]; then
        ph="$(__ps1_bold "$ph")"
    fi
    echo "$ph"
}

create_ph()
{
    local ph
    ph="$(render '%%' $@)"
    ph="${ph//\\[}"
    ph="${ph//\\]}"
    echo "$ph"
}

# Pre-render colors
_PS1_PLACEHOLDER_PREFIX="$(create_ph $COLOR_PREFIX $BOLD_PREFIX)"

# Git Placeholders
_PS1_PLACEHOLDER_GIT_REPO="$(create_ph $COLOR_REPO $BOLD_REPO)"
_PS1_PLACEHOLDER_GIT_BRANCH_DIRTY="$(create_ph $COLOR_BRANCH_DIRTY $BOLD_BRANCH)"
_PS1_PLACEHOLDER_GIT_BRANCH_STAGED="$(create_ph $COLOR_BRANCH_STAGED $BOLD_BRANCH)"
_PS1_PLACEHOLDER_GIT_BRANCH_CLEAN="$(create_ph $COLOR_BRANCH_CLEAN $BOLD_BRANCH)"

_PS1_COLORED_USER="$(render \\u $COLOR_USER $BOLD_USER)"
_PS1_COLORED_HOST="$(render \\h $COLOR_HOST $BOLD_HOST)"
_PS1_COLORED_CWD="$(render \\w $COLOR_CWD $BOLD_CWD)"
_PS1_COLORED_END="$(render \\$ $COLOR_END $BOLD_END)"

_PS1_COLORED_SUCCESS="$(__ps1_sub $(create_ph $COLOR_SUCCESS) "$SYMBOL_SUCCESS")"
_PS1_COLORED_FAIL="$(__ps1_sub $(create_ph $COLOR_FAIL) "$SYMBOL_FAIL")"

_PS1_BASE="${debian_chroot:+($debian_chroot)}$_PS1_COLORED_USER@"
_PS1_BASE+="$_PS1_COLORED_HOST:$_PS1_COLORED_CWD"

PS1='$('
PS1+='ret=$?;'
PS1+='__ps1_prefix;'
if [ "$SHOW_GIT_INFO" -eq 1 ]; then
    PS1+='__ps1_git_info;'
fi
if [ "$SHOW_LAST_RESULT" -eq 1 ]; then
    PS1+='if [[ $ret == 0 ]];'
    PS1+='then printf "$_PS1_COLORED_SUCCESS ";'
    PS1+='else printf "$_PS1_COLORED_FAIL ";'
    PS1+='fi'
fi
PS1+=")$_PS1_BASE"
PS1+="$_PS1_COLORED_END "
export PS1
PROMPT_COMMAND='__ps1_strip_prefix'
