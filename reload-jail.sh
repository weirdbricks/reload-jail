#!/usr/bin/env sh
echo "checking if jail is running.."
jail1_status=`ezjail-admin list | grep jail1 | grep -v grep |wc -l`

create_jail(){
	echo "creating jail1"
  	ezjail-admin create jail1 192.168.2.20 > /dev/null 2>&1
        echo "copying resolv.conf file"
        cp /etc/resolv.conf /usr/jails/jail1/etc/resolv.conf
        echo "remove /usr/bin symlink"
        rm /usr/jails/jail1/usr/bin
        echo "copy the /usr/bin/ directory"
        cp -R -p /usr/jails/basejail/usr/bin /usr/jails/jail1/usr/ > /dev/null
	echo "remove /usr/ports from jail"
	rm /usr/jails/jail1/usr/ports
	echo "create directory to mount host's ports in"
	mkdir /usr/jails/jail1/usr/ports
	echo "mounting host's ports"
	mount_nullfs -o ro /usr/ports/ /usr/jails/jail1/usr/ports
	echo "creating ifconfig alias for 192.168.2.20"
	ifconfig re0 alias 192.168.2.20 netmask 255.255.255.0
	echo "modifying /usr/local/etc/ezjail/jail1 to allow pinging"
	awk '{ gsub("export jail_jail1_parameters=\"\"","export jail_jail1_parameters=\"allow.raw_sockets=1 allow.sysvipc=1\"" ) ; print }' /usr/local/etc/ezjail/jail1 > /usr/local/etc/ezjail/jail1-edited
	rm /usr/local/etc/ezjail/jail1
	mv /usr/local/etc/ezjail/jail1-edited /usr/local/etc/ezjail/jail1
        echo "modifying SSHd configuration"
	awk '{ gsub("#ListenAddress 0.0.0.0","ListenAddress 192.168.2.20" ) ; print }' /usr/jails/jail1/etc/ssh/sshd_config > /usr/jails/jail1/etc/ssh/sshd_config_edited
        rm /usr/jails/jail1/etc/ssh/sshd_config
	awk '{ gsub("#PermitRootLogin no","PermitRootLogin yes"); print }' /usr/jails/jail1/etc/ssh/sshd_config_edited > /usr/jails/jail1/etc/ssh/sshd_config
#	mv /usr/jails/jail1/etc/ssh/sshd_config_edited /usr/jails/jail1/etc/ssh/sshd_config
        echo "setting SSH to start"
	echo 'sshd_enable="YES"' > /usr/jails/jail1/etc/rc.conf
        echo 'creating directory for ssh'
	mkdir /usr/jails/jail1/root/.ssh
        echo "copying ansible-master's key"
	cat /usr/jails/ansible-master/root/.ssh/id_rsa.pub >> /usr/jails/jail1/root/.ssh/authorized_keys
        echo "setting correct SSH key permissions"
        chmod 600 /usr/jails/jail1/root/.ssh/*
	chmod 700 /usr/jails/jail1/root
	echo "OK: jail ready to use - starting it up"
        ezjail-admin start jail1
}

delete_jail(){
	echo "stopping the jail"
	ezjail-admin stop jail1
	echo "unmount ports"
	umount /usr/jails/jail1/usr/ports
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
