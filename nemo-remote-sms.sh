#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2021 Tomi Ollila
#
# Created: Sun 22 Aug 2021 13:29:52 EEST too
# Last modified: Sat 18 Sep 2021 22:59:34 +0300 too
#
# SPDX-License-Identifier: 0BSD

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # and remember to test with /bin/dash -x {thisfile} ...

die () { printf '%s\n' "$@"; exit 1; } >&2

# undocumented test option (and use bash/dash/ksh/zsh -x ... to see more)
test "${1-}" = -n && { arg_test=true; shift; } || arg_test=false

# hmm, since last time i tried this, iirc things worked differently --
# `ssh 0.1` failed immediately if no control socket but now ssh to 0.0.0.1
# is tried. also w/ just `ssh 1` 0.0.0.1 is tried (which is convenient!)
# -- so this code now allows e.g 1-99999, 0.1-0.99999 ...
za () {
	case $1 in ( '' | . | *[!.0-9]* | 0.??????* ) return 1
		;; ( 0.[1-9]* ) ;; ( [1-9]*.* | ??????* ) return 1
	esac
	return 0
}

test $# -ge 3 || {
	exec >&2; echo
	if za "${1-}"
	then
	echo "FIXME: To create ControlPersist execute:"; echo
	echo "  ${0##*/} $1 time[smhdw] [user@]host [command [args]]"
	echo; echo "Then normal Usage: ${0##*/} $1 [+]{number} {message...}"
	echo; echo "See  man sshd_config  for time[smhdw] format."
	else
	echo "Usage: ${0##*/} {hostname/ipaddr|0.1|1} [+]{number} {message...}"
	echo
	echo "Send sms message via nemomobile device ssh connection."
	echo "Message editor on the device is opened for confirmation."
	echo
	echo "'1','0.1'...: special ControlPersists -- fixme helep..." ''
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
