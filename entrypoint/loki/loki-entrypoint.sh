#!/bin/sh

# Use the IP address of the eth0 interface for memberlist binding.
/usr/bin/loki -memberlist.bind-addr=$(/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}') $@
