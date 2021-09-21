#!/bin/sh
#
# template for *-sms wrapper scripts, for creating ssh connection
# and having "names" for phone numbers
#
# copy this to some name and location and edit the block below...
#
# SPDX-License-Identifier: 0BSD

case ${BASH_VERSION-} in *.*) set -o posix; shopt -s xpg_echo; esac
case ${ZSH_VERSION-} in *.*) emulate ksh; esac

set -euf  # hint: sh -x thisfile [args] to trace execution


# ------ the part user is expected to edit at least ------ #

cmdpath='./'  # remember to keep trailing '/' when editing

rhost=192.168.2.15
#rhost=192.168.0.35

# edit for sure; dummies (note that default `sms` runs in "dry-run" mode...)
names='
usar +123456788888
rusr +765432100000
'
# note: prefix match done, first match taken below (was simplest to implement)

# ----- end of the variables user is expected to edit ----- #


saved_IFS=$IFS; readonly saved_IFS

NL='
'
readonly NL

warn () { printf '%s\n' "$@"; } >&2
die () { printf '%s\n' "$@"; exit 1; } >&2

x () { printf '+ %s\n' "$*" >&2; "$@"; }
x_bg () { printf '+ %s\n' "$*" >&2; "$@" & }
x_env () { printf '+ %s\n' "$*" >&2; env "$@"; }
x_eval () { printf '+ %s\n' "$*" >&2; eval "$*"; }
x_exec () { printf '+ %s\n' "$*" >&2; exec "$@"; die "exec '$*' failed"; }

test $# -ge 3 || die "Usage: $0 [[user]@]host|.|''|- name message..."
case $1 in '.' ) r=nemo@$rhost
	;; ''|-) r= # use nemo-sms.sh
	;; 0.* ) r=$1
	;; [1-9] | [1-9][0-9] | [1-9][0-9][0-9] ) r=$1
	;; [1-9][0-9][0-9][0-9] | [1-9][0-9][0-9][0-9][0-9] ) r=$1
	;; *@* ) r=${1#@} # e.g. @0.1 -> 0.1 ...
	;; * )   r=nemo@$1 # ... otherwise nemo@
esac

IFS=$NL
n=
for name in $names
do
	case $name in $2*) n=$name; break; esac
done
IFS=$saved_IFS
test "$n" || die "Cannot find number for '$2'"
n=${n#* }
shift 2
#x_exec () { echo "$@"; exit; } # outcomment for "dry-run" test
if test "$r"
then x_exec $cmdpath''nemo-remote-sms.sh "$r" "$n" "$@"
else x_exec $cmdpath''nemo-sms.sh "$n" "$@"
fi


# Local variables:
# mode: shell-script
# sh-basic-offset: 8
# tab-width: 8
# End:
# vi: set sw=8 ts=8
