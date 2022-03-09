#!/bin/sh

# Fix permissions for WAL ingester (https://github.com/grafana/loki/issues/2018)
mkdir -p /loki/wal
chown 10001:10001 /loki/wal

# Use the IP address of the eth0 interface for memberlist binding.
/usr/bin/loki -memberlist.bind-addr=$(/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}') $@