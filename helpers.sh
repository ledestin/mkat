#!/bin/bash
# vim: set filetype=sh:
#shellscript helper functions

function debug {
  [ -z $DEBUG ] || echo "$@"
}

NO_PREFIX='--no'
MACROS=(
'=FOO' 'FOO="$2"'
'@FOO' 'FOO[${#FOO}]="$2"'
'*FOO' 'cnt=${1##-}; let "FOO += $cnt"'
'?FOO' '[ "${1:0:${#NO_PREFIX}}" != $NO_PREFIX ] && FOO=1'
)

function get_macro {
  i=0
  while [ ! -z "${MACROS[$i]}" ]; do
    if [ "$1" = "${MACROS[$i]}" ]; then
      echo ${MACROS[$(($i+1))]}
      return 0
    fi
    let "i += 1"
  done
  return 1
}

#print_usage($options)
#print usage: screen for passed CLI options
function print_usage {
  local i=0
  while [ ${#OPTIONS[@]} -ge $i ] ; do
    local opt="${OPTIONS[$i]}"; local desc="${OPTIONS[$(($i+1))]}"
    opt=${opt//=/ }
    printf '  %-15s%-25s\n' "${opt//|/,}" "$desc"
    i=$(($i+3))
  done
}

#process_options($options)
#process a program's arguments, which means,
#execute code attached to an option with eval
function process_options {
  local i=0 pos
  while [ ${#*} -gt 0 ]; do
    local o=${OPTIONS[$i]}
    while [ `expr index "$o" '|'` -ne 0 ]; do
      found=${o%%|*}
      if [ "${found%=*}" = "$1" ]; then
	o=$found; break
      fi
      o=${o#*|}
    done
    if [ "${o%=*}" = "$1" ]; then
      #debug "found argument: $1"
      local pos=`expr index "$o" =`
      #make sure that $2 is a param if option requires one
      if [ $pos -ne 0 ]; then
	[ ${2:0:1} != '-' ] || \
	  { echo "option $o requires parameter"; exit 1; }
      fi
      #execute action associated with the option
      local varname=''; local action=''
      for word in ${OPTIONS[$(($i+2))]}; do
	letter_one=${word:0:1};
	case $letter_one in
	  '='|'@'|'*'|'?') varname=${word:1} ;;
	esac
	if [ $varname ]; then
	  macro=$(get_macro "${letter_one}FOO")
	  action="$action ${macro//FOO/$varname}"
	else
	  action="$action $word"
	fi
      done
      debug "action: $action"
      eval "$action"
      if [ $pos -ne 0 ]; then
	shift 2
      else
        shift
      fi
      i=0; continue
    fi
    i=$(($i+3))
    [ $i -gt ${#OPTIONS[@]} ] && { echo >&2 "unknown option: $1"; exit 1; }
  done
}

function test_helpers {
  DEBUG=1
  OPTIONS=(\
  -f force '?FORCE' \
  --rc=RCFILE 'read this config file' 'CONFIG=$2')
  process_options -f --rc file.conf
  [ $FORCE ] && echo OK
  [ $CONFIG = 'file.conf' ] && echo OK
  echo "usage:"; print_usage "${OPTIONS[@]}"
}
if [ ${0##*/} = helpers.sh ]; then
  test_helpers
fi
