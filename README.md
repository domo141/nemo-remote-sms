
Send SMS messages from terminal, passing message to "nemomobile"
device through ssh connection and sending it from there.

SMS UI on device is opened for confirmation (message may
be edited further before sending).

While `nemo-remote-sms.sh` processes the message, the
characters `'` (apostrophes) in message are "escaped" as
`'"'"'` (multiples as `'"''"'`, `'"'''"'` and so on) before
inserting the message to ssh command line as `"'$msg'"`.
This way it is expanded correctly by the (posix-compatible)
shell on the device.

The other script, `nemo-sms.sh` initiates SMS sending on
the device itself...

This implementation uses the dbus-send options found in

https://together.jolla.com/question/17992/sending-an-sms-via-the-command-line/

for initiating the SMS send.

The scripts `nemo-remote-sms.sh` and `nemo-sms.sh` do not have
any name to number substitutions nor write to any (log) files
(like e.g. MessaGGiero/jollaSms does). For such purposes one
can copy `tmpl.sh` to another name and extend it to have
the desired "alias names"...

The `tmpl.sh` may have good enough comments on ways how to use it...
