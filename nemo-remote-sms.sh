#!/bin/sh
#
# Author: Tomi Ollila -- too ät iki piste fi
#
#	Copyright (c) 2021 Tomi Ollila
#
# Created: Sun 22 Aug 2021 13:29:52 EEST too
# Last modified: Tue 07 Sep 2021 22:46:21 +0300 too
#
# SPDX-License-Identifier: 0BSD

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # and remember to test with /bin/dash -x {thisfile} ...

die () { printf '%s\n' "$@"; exit 1; } >&2

# undocumented test option (and use bash/dash/ksh/zsh -x ... to see more)
test "${1-}" = -n && { arg_test=true; shift; } || arg_test=false

test $# -ge 3 ||
	die '' "Usage: ${0##*/} {hostname/ipaddr} [+]{number} {message...}" ''\
		"Send sms message via nemomobile device ssh connection." \
		"Message editor on the device is opened for confirmation." ''

case $1 in *@*) userathost=$1
	;; *) userathost=nemo@$1
esac
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

ssh=${NEMO_REMOTE_SMS_SSH_COMMAND:-ssh} # analogous to GIT_SSH_COMMAND

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
exec $ssh $userathost $exec dbus-send --type=method_call --print-reply \
	--dest=org.nemomobile.qmlmessages \
	/ org.nemomobile.qmlmessages.startSMS array:string:$num string:"'$msg'"

exit # -- exit here (if not above) -- the following code NOT REACHED -- #

printf %s\\n \
exec $ssh $userathost $exec devel-su dbus-send --system --print-reply \
	--dest=org.ofono /ril_0 org.ofono.MessageManager.SendMessage \
	string:$num string:"'$msg'"
