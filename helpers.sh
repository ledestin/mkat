#!/bin/bash
# vim: set filetype=sh:
#shellscript helper functions

function debug {
  [ -z $DEBUG ] || echo "$@"
}

NO_PREFIX='--no'
#\n is ignored later on, so please write as if \n's weren't present,
#i.e. with ';'s everywhere
MACROS=(
'=FOO' 'FOO="$2"'
'@FOO'
'[ `expr index "$o" ,` -ne 0 ] && IFS=,;
  FOO=("${FOO[@]}" $2); unset IFS;'
'*FOO' '_s=${1#-}; let "FOO += ${#_s}"'
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
    printf '  %-18s%-25s\n' "${opt//|/,}" "$desc"
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
    #deal with -h|--help like options
    while [ `expr index "$o" '|'` -ne 0 ]; do
      found=${o%%|*}
      if [ "${found%=*}" = "$1" ]; then
	#add =VALUE to short option if long is --o=VALUE
	[ `expr index "$o" =` -ne 0 ] && \
	  [ ${1:0:2} != '--' ] && [ ! -z ${o#*=} ] && found="$found=${o#*=}"
	o=$found; break
      fi
      o=${o#*|}
    done
    #allow repitition for short options w/o parameters
    cur_opt="$1"
    local s=${1:1}
    [ "${s:0:1}" != '-' ] && [ `expr index "$s" =` -eq 0 ] && \
      [ ${#s} -gt 1 ] && [ -z "${s//${s:0:1}/}" ] && \
	cur_opt="-${s:0:1}"
    #process argument
    if [ "${o%=*}" = "$cur_opt" ] || [ "--no${o%=*}" = "$cur_opt" ]; then
      #debug "found argument: $1"
      local pos=`expr index "$o" =`
      #make sure that $2 is a param if option requires one
      if [ $pos -ne 0 ]; then
	([ "$2" ] && [ ${2:0:1} != '-' ]) || \
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

function assert {
  text="$1 || { echo >&2 assert failed: \$2; exit 1; }"
  #debug "$text"
  eval "$text"
}

function test_helpers {
  DEBUG=1
  OPTIONS=(\
  -f force '?FORCE' \
  --rc=RCFILE 'read this config file' 'CONFIG=$2'
  -t=TAG1,TAG2 'multiple times option' '@TAGS'
  -r 'boolean option' '?RECURSIVE'
  -v 'verbose' '*VERBOSE_LEVEL'
  )
  cmd='process_options -f --rc file.conf -v -vv -t tag1 -t tag2,tag3 --no-r'
  echo $cmd; eval "$cmd"

  assert '[ $FORCE ]' '-f option specified, but FORCE is not set'
  assert '[ $CONFIG = file.conf ]' \
    "config file isn't the one specified with --rc option"
  assert '[ ${#TAGS[@]} -eq 3 ]' "3 -t options specified, but ${#TAGS} found"
  assert '[ ${TAGS[0]} = tag1 ] && \
    [ ${TAGS[1]} = tag2 ] && [ ${TAGS[2]} = tag3 ]' "tag names are wrong"
  assert '[ -z $RECURSIVE ]' '--no-r should yield non-existing $RECURSIVE'
  assert '[ $VERBOSE_LEVEL -eq 3 ]' \
    "verbose option was specified 2 times, but \$VERBOSE_LEVEL is $VERBOSE_LEVEL"
  echo "usage:"; print_usage "${OPTIONS[@]}"
}
if [ ${0##*/} = helpers.sh ]; then
  test_helpers
fi
