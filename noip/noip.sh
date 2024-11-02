#!/bin/bash
IP=`/sbin/ifconfig wlan0| grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
echo "Changing IP to $IP\n at $(date)"
/usr/local/bin/noip2 -i $IP

