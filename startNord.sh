#!/bin/bash

if [ $# -eq 1 ]; then
    sudo openvpn --config /etc/openvpn/ovpn_udp/$1.udp.ovpn --auth-user-pass ~/Documents/nordpass.txt
else
	sudo openvpn --config /etc/openvpn/ovpn_udp/uk2015.nordvpn.com.udp.ovpn --auth-user-pass ~/Documents/nordpass.txt
	#sudo openvpn --config /etc/openvpn/ovpn_udp/in122.nordvpn.com.udp.ovpn --auth-user-pass ~/Documents/nordpass.txt
fi
