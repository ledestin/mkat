# This file is part of Mkat
#
# Copyright (C) 2005, 2013 Dmitry Maksyoma <ledestin at gmail.com>.
#
# Mkat is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
# USA.

#This library provides shell helper functions,
#including Ruby optparse-like option handling

RET='
'

#load_config(config)
function load_config {
  [ -f "$1" ] && . "$1" || return 1
  #eval variables
  for v in DRIVE CD LISTDIR TMP ISO_IMAGE; do
    eval "val=\"\$$v\""; eval "$v=\"$val\""
  done
  return 0
}

#fail_unless_defined(var_names)
function fail_unless_defined {
  for v in $@; do
    eval "[ -z \"\$$v\" ] && 
      { error '"$v" variable must be defined (see mkatrc(5))'; exit 1; }"
  done
}

#usage(exitcode) prints BANNERS, program OPTIONS
#and exits with exitcode
function usage {
  local SCRIPT=`basename $0`
  for b in "${BANNERS[@]}"; do
    echo "usage: $SCRIPT $b"
  done
  print_usage
  exit $1
}

#debug(msg)
function debug {
  [ -z $DEBUG ] || echo "$@"
}

#error(msg)
function error {
  echo >&2 ERROR: "$@"
}

function hint {
  echo >&2 "Hint: $@"
}

#quit(msg, exitcode)
function quit {
  error $1; exit $2
}

#make_dir(dir)
function make_dir {
  if [ ! -d "$1" ]; then
    mkdir -p "$1" >/dev/null 2>&1
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
   FOO=("${FOO[@]}" "$2");
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
#Process a program's arguments, which means,
#execute code attached to an option with eval.
#After the options with respectable arguments have been processed, the
#non-option parameters are stored into the ARGUMENTS array.
function process_options {
  local i=0 found REQUIRES_PARAM SHORT_OPTION cur_opt
  while [ ${#*} -gt 0 ]; do
    #support for arguments after options have been specified
    if [ "_${1:0:1}" != "_-" ]; then 
      #check that there are no options to the right of this argument
      for ao in "$@"; do
	[ "_${ao:0:1}" = "_-" ] && \
	  { error "several arguments are allowed after options only: $1"; \
	  exit 1; }
	ARGUMENTS=("${ARGUMENTS[@]}" "$1"); shift
      done
      continue
    fi
    local o=${OPTIONS[$i]}
    unset REQUIRES_PARAM; [ `expr index "$o" =` -ne 0 ] && REQUIRES_PARAM=1
    unset SHORT_OPTION; [ "_${1:0:2}" != '_--' ] && SHORT_OPTION=1
    #split short option to several short options if $o.len > 2, e.g. -vd
    if [ $SHORT_OPTION ] && [ "_${o:0:2}" = "_${1:0:2}" ] && [ ${#1} -gt 2 ]; then
      cur_opt=$1; local j=2;
      if [ $REQUIRES_PARAM ]; then
	expd[0]=${1:2}
      else
	while [ ${#1} -gt $j ]; do
	  expd=(${expd[@]} -${1:$j:1})
	  let "j += 1"
	done
      fi
      shift; set - ${cur_opt:0:2} ${expd[@]} "$@" 
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
  cmd='process_options -f --rc file.conf -v -vvd -t tag1 -t tag2,tag3 --no-r arg1 arg2'
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
  assert '[ "_${ARGUMENTS[*]}" = "_arg1 arg2" ]' \
    'additional argument is: "${ARGUMENTS[@]}"'
  echo "usage:"; print_usage "${OPTIONS[@]}"
}
if [ ${0##*/} = helpers.sh ]; then
  test_helpers
fi
