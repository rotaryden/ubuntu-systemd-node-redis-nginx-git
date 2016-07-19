#!/bin/sh
IP=`cat $(dirname $(readlink -f $0))/_vps_ip`
ssh web@${IP} "rm -rf /www/webapp/$1/$2/node_modules"
