#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2021 Tomi Ollila
#
# Created: Sun 22 Aug 2021 13:29:52 EEST too
# Last modified: Sun 26 Sep 2021 20:26:25 +0300 too
#
# SPDX-License-Identifier: 0BSD

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # and remember to test with /bin/dash -x {thisfile} ...

die () { printf '%s\n' "$@"; exit 1; } >&2

# undocumented test option (and use bash/dash/ksh/zsh -x ... to see more)
test "${1-}" = -n && { arg_test=true; shift; } || arg_test=false

userathost () {
	case $1 in @*) userathost=${1#?}
		;; *@*) userathost=$1
		;; *) userathost=nemo@$1
	esac
}

# better configure ControlPath in ~/.ssh/config, but if not outcomment 2nd line
so=
#so=-oControlPath=$XDG_RUNTIME_DIR/ssh-controlpath-%r@%h:%p

test $# -ge 3 || {
	exec >&2; echo
	case $0 in ./*) n=$0 ;; *) n=${0##*/} ;; esac
	# a subset of "invalid hostnames" -- for this help
	case ${1-1} in ( '' | [.%]* | *[.%][.%]* | *@[.%]* )
	echo "The hostname \"$1\" is invalid as an internet host name."
	echo "Such a name cannot be resolved to an internet address."
	echo "But it may be used as a name to find (open)ssh persistent"
	echo "connection socket. The following built-in usage can be used"
	echo "to create persistent connection socket:"
	echo
	echo ":  $n $1 {time}(s|m|h|d|w) [[user]@]{host} [command [args]]"
	echo
	echo ": E.g.;  $n $1 5m 192.168.2.15"
	echo
	echo "Note that in place of \"$1\" anything ssh accepts works, e.g."
	echo "valid internet names. \"$1\" was used just to trigger this help."
	echo
	echo "Then normal Usage: ${0##*/} $1 [+]{number} message..."
	test "$so" || { userathost "$1";echo "As well also: ssh $userathost"; }
	;; *)
	echo "Usage: $n [[user]@]{hostname/ipaddr|.} [+]{number} message..."
	echo
	echo "Send sms message via nemomobile device ssh connection."
	echo "Message editor on the device is opened for confirmation."
	echo
	echo "Plain 'hostname' is changed to 'nemo@hostname', and '@hostname'"
	echo "just to 'hostname' -- this is to simplify default access..."
	echo
	echo ": '.' resembles a \"hostname\" that is not resolvable, but"
	echo ": (open)ssh can access via existing ControlPath socket."
	echo ": Execute;  $n .  ;: for more information."
	esac; echo; exit 1
}

case $2 in *[!0-9]*[smhdw]) # not a number following [smhdw]
	;; [1-9]*[smhdw])
		echo "Checking/creating persistent connection lasting $2"
		userathost "$1"
		z=`ssh $so -O check "$userathost" 2>&1` &&
		{ echo $z; exit 0; } ||
		case $z in 'No ControlPath specified'*)
			echo $z
			exit 1
		esac
		z=${z%)*}; z=${z#*\(}
		test -e "$z" && rm "$z"
		so=-oControlPath=$z\ -M\ -oControlPersist=$2
		i=$userathost; userathost "$3"
		shift 3
		test $# = 0 && set -- echo ": ok ';' ssh $i"
		echo ssh $so $userathost "$@" >&2
		exec ssh $so $userathost "$@"
		exit not reached
	# ;; *)
esac

userathost "$1"
shift

case $1
in +*)	test ${#1} -ge 12 || die "Phone number '$1' suspiciously short"
;; *)	test ${#1} -ge 10 || die "Phone number '$1' suspiciously short"
esac

case ${1#+} in *[!0-9]*) die "'${1#+}' contains non-numeric data"
esac

num=$1
shift

msg=$*

test ${#msg} -le 400 || die "Message too long (${#msg} > 400)"

# do replacements like the following:  ''' -> '" ''' "' (w/o spaces)

msg=$(printf %s "$msg" | sed "s/\(''*\)/'"'"\1"'"'/g")

ssh=${NEMO_REMOTE_SMS_RSH_COMMAND:-ssh} # like RSYNC_RSH and GIT_SSH_COMMAND

if $arg_test
then
	exec='printf %s\\n'
else
	exec=exec
	echo $ssh $userathost dbus-send ... $num ... $msg
fi

# dbus-send options from answer of CsTom (updated 2014-01-24)
# https://together.jolla.com/question/17992/sending-an-sms-via-the-command-line/

# ssh concatenates command line and uses shell to execute it.

#printf %s\\n \
exec $ssh $so $userathost $exec dbus-send --type=method_call --print-reply \
	--dest=org.nemomobile.qmlmessages \
	/ org.nemomobile.qmlmessages.startSMS array:string:$num string:"'$msg'"

exit # -- exit here (if not above) -- the following code NOT REACHED -- #

printf %s\\n \
exec $ssh $so $userathost $exec devel-su dbus-send --system --print-reply \
	--dest=org.ofono /ril_0 org.ofono.MessageManager.SendMessage \
	string:$num string:"'$msg'"
