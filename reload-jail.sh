#!/usr/bin/env sh
echo "checking if jail is running.."
jail1_status=`ezjail-admin list | grep jail1 | grep -v grep |wc -l`

create_jail(){
	echo "creating jail1"
  	ezjail-admin create jail1 192.168.2.20
        echo "copying resolv.conf file"
        cp /etc/resolv.conf /usr/jails/jail1/etc/resolv.conf
        echo "remove /usr/bin symlink"
        rm /usr/jails/jail1/usr/bin
        echo "copy the /usr/bin/ directory"
        cp -R -p /usr/jails/basejail/usr/bin /usr/jails/jail1/usr/
	echo "creating ifconfig alias for 192.168.2.20"
	ifconfig re0 alias 192.168.2.20 netmask 255.255.255.0
	echo "modifying /usr/local/etc/ezjail/jail1 to allow pinging"
	cd /usr/local/etc/ezjail/
	awk '{ gsub("export jail_jail1_parameters=\"\"","export jail_jail1_parameters=\"allow.raw_sockets=1 allow.sysvipc=1\"" ) ; print }' jail1 > jail1-edited
	rm jail1
	mv jail1-edited jail1
	echo "OK: jail ready to use - starting it up"
        ezjail-admin start jail1
}

delete_jail(){
	echo "stopping the jail"
	ezjail-admin stop jail1
	echo "deleting the jail"
	ezjail-admin delete jail1
	echo "fixing permissions"
	chflags -R noschg /usr/jails/jail1
	echo "deleting remaining files"
	rm -r -f /usr/jails/jail1
	echo "jail completely deleted"
}



if [ $jail1_status -eq 0 ];
then 
	echo "jail doesn't exist - getting it ready"
        create_jail
else
	echo "yup, jail is running - deleting"
	delete_jail
	echo "and rebuilding"
	create_jail
fi
