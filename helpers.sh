#!/bin/bash
# vim: set filetype=sh:
#shellscript helper functions

function debug {
  [ -z $DEBUG ] || echo "$@"
}

function error {
  echo >&2 error: "$@"
}

function make_dir {
  if [ ! -d $1 ]; then
    mkdir -p $1 >/dev/null 2>&1
    [ $? -eq 0 ] || exit 1
  fi
}

NO_PREFIX='--no'
#\n is ignored later on, so please write as if \n's weren't present,
#i.e. with ';'s everywhere
MACROS=(
'=FOO' 'FOO="$2"'
'@FOO'
'if [ "_${o#*,}" != "_$o" ]; then
   IFS=,; FOO=("${FOO[@]}" $2); unset IFS;
 else
   FOO="$2";
 fi'
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

#process_options($*)
#process a program's arguments, which means,
#execute code attached to an option with eval
function process_options {
  local i=0 found REQUIRES_PARAM SHORT_OPTION cur_opt
  while [ ${#*} -gt 0 ]; do
    local o=${OPTIONS[$i]}
    unset REQUIRES_PARAM; [ `expr index "$o" =` -ne 0 ] && REQUIRES_PARAM=1
    unset SHORT_OPTION; [ "_${1:0:2}" != '_--' ] && SHORT_OPTION=1
    #split short option to several short options if $o.len > 2, e.g. -vd
    if [ $SHORT_OPTION ] && [ ${#1} -gt 2 ]; then
      cur_opt=$1; local j=2;
      while [ ${#1} -gt $j ]; do
	expd=(${expd[@]} -${1:$j:1})
	let "j += 1"
      done
      shift; set - ${cur_opt:0:2} "$@" ${expd[@]}
    fi
    
    #deal with -h|--help like options
    while [ `expr index "$o" '|'` -ne 0 ]; do
      found=${o%%|*}
      if [ "${found%=*}" = "$1" ]; then
	#add =VALUE to short option if long is --o=VALUE
	[ $REQUIRES_PARAM ] && \
	  [ ${1:0:2} != '--' ] && [ ! -z ${o#*=} ] && found="$found=${o#*=}"
	o=$found; break
      fi
      o=${o#*|}
    done
    #process cur_opt
    if [ "${o%=*}" = "$1" ] || [ "--no${o}" = "$1" ]; then
      #debug "found argument: $1"
      #make sure that $2 is a param if option requires one
      if [ $REQUIRES_PARAM ]; then
	([ "$2" ] && [ ${2:0:1} != '-' ]) || \
	  { echo "option ${o//=/ } requires parameter"; exit 1; }
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
      shift
      #shift parameter as well if option has one
      [ $REQUIRES_PARAM ] && shift
      #will process the next positional argument, so OPTIONS will be cycled
      #from the start, hence i=0
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
  -d 'debug' '*DEBUG_LEVEL'
  )
  cmd='process_options -f --rc file.conf -v -vvd -t tag1 -t tag2,tag3 --no-r'
  echo $cmd; eval "$cmd"

  assert '[ $FORCE ]' '-f option specified, but FORCE is not set'
  assert '[ $CONFIG = file.conf ]' \
    "config file isn't the one specified with --rc option"
  assert '[ ${#TAGS[@]} -eq 3 ]' "3 -t options specified, but ${#TAGS} found"
  assert '[ "_${TAGS[*]}" = "_tag1 tag2 tag3" ]' "tag names are wrong"
  assert '[ -z $RECURSIVE ]' '--no-r should yield non-existing $RECURSIVE'
  assert '[ $VERBOSE_LEVEL -eq 3 ]' \
    "verbose option was specified 3 times, but \$VERBOSE_LEVEL is $VERBOSE_LEVEL"
  assert '[ $DEBUG_LEVEL -eq 1 ]' \
    "debug option was specified 1 times, but \$DEBUG_LEVEL is $DEBUG_LEVEL"
  echo "usage:"; print_usage "${OPTIONS[@]}"
}
if [ ${0##*/} = helpers.sh ]; then
  test_helpers
fi
