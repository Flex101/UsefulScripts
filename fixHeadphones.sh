#!/usr/bin/env bash

device="00:6A:8E:0C:B0:D6"
/usr/bin/expect <(
	cat <<EOF
set timeout 60
spawn bluetoothctl
send -- "remove $device\r"
expect "Device*"
send -- "scan on\r"
expect "*NEW*$device*"
send -- "pair $device\r"
expect "Pairing successful"
send -- "connect $device\r"
expect "Connection successful"
send -- "trust $device\r"
expect "trust succeeded"
send -- "exit\r"
expect eof
EOF
)
