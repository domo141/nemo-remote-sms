#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2021 Tomi Ollila
#
# Created: Sun 22 Aug 2021 13:29:52 EEST too
# Last modified: Tue 21 Sep 2021 00:40:00 +0300 too
#
# SPDX-License-Identifier: 0BSD

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # and remember to test with /bin/dash -x {thisfile} ...

die () { printf '%s\n' "$@"; exit 1; } >&2

# undocumented test option (and use bash/dash/ksh/zsh -x ... to see more)
test "${1-}" = -n && { arg_test=true; shift; } || arg_test=false


# For address block 0.0.0.0/8, rfc6890: Special-Purpose IP Address Registries
# says it is "This host on this network" address range. It points to rfc 1122:
# Requirements for Internet Hosts -- Communication Layers section 3.2.1.3
# which states:  (b) { 0, <Host-number> }
#   Specified host on this network.  It MUST NOT be sent,
#   except as a source address as part of an initialization
#   procedure by which the host learns its full IP address.
#
# Older Linux kernels (tested 2.6.32, 3.10) will EINVAL immediately when one
# executes `ssh 0.1` (or just `ssh 1`). Later Linux kernels (tested 5.5) will
# at least try to connect
# (tested with strace, waits for connect(2) to complete).
# In any way, this code will have special handling for addresses in range
# 1-99999, 0.1-0.99999 (and e.g. 0.1.2.3 (matches 0.????? and all chars in
# set [.0-9]) -- ssh persistent connection socket which is found by giving
# such an ip can be created, with real connection established to another
# address. (how? see the block with z=`ssh $so -O check "$1" 2>&1` below).


za () {
	case $1 in ( '' | . | *[!.0-9]* | 0.??????* ) return 1
		;; ( 0.[1-9]* ) ;; ( [1-9]*.* | ??????* ) return 1
	esac
	return 0
}

test $# -ge 3 || {
	exec >&2; echo
	case $0 in ./*) n=$0 ;; *) n=${0##*/} ;; esac
	if za "${1-}"
	then
	echo "The address '$1' is" '"resolved" as being address in 0.A.B.C'
	echo "range. Such an address should not be accepted as destination"
	echo "address (only as source but...). Here the trick is to use such"
	echo "an address as name to find ssh persistent connection socket."
	echo
	echo "Usage to create persistent connection socket:"; echo
	echo "  $n $1 {time}(s|m|h|d|w) [user@]{host} [command [args]]"
	echo; echo "E.g.  $n $1 5m 192.168.2.15"
	echo; echo "Then normal Usage: ${0##*/} $1 [+]{number} {message...}"
	else
	echo "Usage: $n {hostname/ipaddr|0.1|1} [+]{number} {message...}"
	echo
	echo "Send sms message via nemomobile device ssh connection."
	echo "Message editor on the device is opened for confirmation."
	echo
	echo "'0.1', '1', '2'...: create/use persistent connection socket..."
	echo "Execute e.g.  $n 0.333  for more information."
	fi; echo; exit 1
}

# better configure ControlPath in ~/.ssh/config, but if not outcomment 2nd line
so=
#so=-oControlPath=$XDG_RUNTIME_DIR/ssh-controlpath-%r@%h:%p

if za "$1"
then	case $2 in *[!0-9]*[smhdw]) # not
		;; [1-9]*[smhdw])
			z=`ssh $so -O check "$1" 2>&1` && { echo $z;exit 0; } ||
			case $z in 'No ControlPath specified'*)
				echo $z
				exit 1
			esac
			z=${z%)*}; z=${z#*\(}
			test -e "$z" && rm "$z"
			so=-oControlPath=$z\ -M\ -oControlPersist=$2
			case $3 in *@*) userathost=$3
				;; *) userathost=nemo@$3
			esac
			i=$1; shift 3
			test $# = 0 && set -- echo ": ok ';' ssh $i"
			echo ssh $so $userathost "$@" >&2
			exec ssh $so $userathost "$@"
			exit not reached
	esac
	userathost=$1
else
	so=
	case $1 in *@*) userathost=$1
		;; *) userathost=nemo@$1
	esac
fi
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
