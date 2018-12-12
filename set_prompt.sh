#!/bin/bash
# Custom bash prompt
# Usage: add `source set_prompt.sh` to your .bashrc

PS1_CONFIG_FILE="${HOME}/.config/ps1"

strip_brackets()
{
    s="${1//\\[}"
    printf "${s//\\]}"
}

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

RESET='\[\e[0m\]'
RESET_UNESCAPED='\e[0m'

BOLD='\[\e[1m\]'
BOLD_UNESCAPED='\e[1m'

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
    printf '%s%s%s' $COLOR "$TEXT" "$RESET"
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
        if [ -z "$BRANCH" ]; then
            BRANCH="$(git status 2> /dev/null | grep -oP '(?<=On branch ).*')"
        else
            BRANCH="${BRANCH//\(}"
            BRANCH="${BRANCH//\)}"
        fi
        printf "$BRANCH"
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
    if [ ! -z "${VIRTUAL_ENV+x}" ]; then
        pref+=("$(basename "$VIRTUAL_ENV")")
    fi
    if [ ! -z "${VIRTUAL_ENV_TOOLS+x}" ]; then
        pref+=("${ENV_NAME_TOOLS}-tools")
    fi
    if [[ "${#pref}" == 0 ]]; then
        return 1
    fi
    pref="$(__ps1_trim "$(__ps1_join_by '; ' ${pref[@]})")"
    printf "($pref) "
    return 0
}

do_bold()
{
    [[ $1 == 1 ]] && printf "$BOLD_UNESCAPED"
}

git_dirty()
{
    git status | grep -E "Changes not staged|Untracked files|Unmerged Paths" > /dev/null
}

git_staged()
{
    git status | grep 'Changes to be committed' > /dev/null
}

# Pre-render colors
COLOR_PREFIX="$(strip_brackets "$(__ps1_color_start $COLOR_PREFIX)")"
BOLD_PREFIX="$(do_bold $BOLD_PREFIX)"

COLOR_REPO="$(strip_brackets "$(__ps1_color_start $COLOR_REPO)")"
BOLD_REPO="$(do_bold $BOLD_REPO)"

COLOR_BRANCH_DIRTY="$(strip_brackets "$(__ps1_color_start $COLOR_BRANCH_DIRTY)")"
COLOR_BRANCH_STAGED="$(strip_brackets "$(__ps1_color_start $COLOR_BRANCH_STAGED)")"
COLOR_BRANCH_CLEAN="$(strip_brackets "$(__ps1_color_start $COLOR_BRANCH_CLEAN)")"
BOLD_BRANCH="$(do_bold $BOLD_BRANCH)"

COLOR_SUCCESS="$(strip_brackets "$(__ps1_color_start $COLOR_SUCCESS)")"
COLOR_FAIL="$(strip_brackets "$(__ps1_color_start $COLOR_FAIL)")"
BOLD_LAST_RESULT="$(do_bold $BOLD_LAST_RESULT)"

COLOR_USER="$(strip_brackets "$(__ps1_color_start $COLOR_USER)")"
BOLD_USER="$(do_bold $BOLD_USER)"
COLOR_HOST="$(strip_brackets "$(__ps1_color_start $COLOR_HOST)")"
BOLD_HOST="$(do_bold $BOLD_HOST)"
COLOR_CWD="$(strip_brackets "$(__ps1_color_start $COLOR_CWD)")"
BOLD_CWD="$(do_bold $BOLD_CWD)"
COLOR_END="$(strip_brackets "$(__ps1_color_start $COLOR_END)")"
BOLD_END="$(do_bold $BOLD_END)"

PS1='$('
PS1+='ret=$?;'
PS1+='prefix="$(__ps1_prefix)";'
PS1+='if [[ $? == 0 ]]; then '
PS1+='printf "\[$BOLD_PREFIX$COLOR_PREFIX\]$prefix\[$RESET_UNESCAPED\]";'
PS1+='fi;'
if [[ $SHOW_GIT_INFO == 1 ]]; then
#     PS1+='printf "\[$(__ps1_git_info)\]" && tput el1;'
    PS1+='if git status &> /dev/null; then '
    PS1+='printf "(";'
    PS1+='printf "\[$BOLD_REPO$COLOR_REPO\]$(__ps1_git_repo)\[$RESET_UNESCAPED\]: ";'
    PS1+='printf "\[$BOLD_BRANCH";'
    PS1+='if git_dirty; then '
    PS1+='printf "$COLOR_BRANCH_DIRTY";'
    PS1+='elif git_staged; then ';
    PS1+='printf "$COLOR_BRANCH_STAGED";'
    PS1+='else ';
    PS1+='printf "$COLOR_BRANCH_CLEAN";'
    PS1+='fi;'
    PS1+='printf "\]$(__ps1_git_branch)\[$RESET_UNESCAPED\])";'
    PS1+='printf "\n\[$RESET_UNESCAPED\]";'
    PS1+='fi;'
fi
if [ "$SHOW_LAST_RESULT" -eq 1 ]; then
    PS1+='printf "\[$BOLD_LAST_RESULT";'
    PS1+='if [[ $ret == 0 ]]; then '
    PS1+='printf "$COLOR_SUCCESS\]$SYMBOL_SUCCESS";'
    PS1+='else '
    PS1+='printf "$COLOR_FAIL\]$SYMBOL_FAIL";'
    PS1+='fi;'
    PS1+='printf "\[$RESET_UNESCAPED\] ";'
fi
PS1+=")${debian_chroot:+($debian_chroot)}"
PS1+="\[$BOLD_USER$COLOR_USER\]\\u\[$RESET_UNESCAPED\]@"
PS1+="\[$BOLD_HOST$COLOR_HOST\]\\h\[$RESET_UNESCAPED\]:"
PS1+="\[$BOLD_CWD$COLOR_CWD\]\\w\[$RESET_UNESCAPED\]"
PS1+="\[$BOLD_END$COLOR_END\]\\$\[$RESET_UNESCAPED\] "
export PS1
PROMPT_COMMAND='__ps1_strip_prefix'
