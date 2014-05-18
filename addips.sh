#!/bin/sh

#will add back the aliases for any jails created
#start it by adding it to /etc/crontab with a line like this:
#@reboot root /root/reload-jail/addips.sh

dir_var=`/usr/local/bin/ezjail-admin list | egrep -v '\-----|Hostname|N/A' | awk '{print $3}'`
nic1=`netstat -rn | grep default | awk '{print $6}'`

for ipaddress in $dir_var
do
   ifconfig $nic1 alias $ipaddress netmask 255.255.255.0
done
