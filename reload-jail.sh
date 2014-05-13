#!/usr/bin/env sh
echo "checking if jail is running.."
jail1_status=`ezjail-admin list | grep jail1 | grep -v grep |wc -l`

ipaddress=192.168.2.101
nic1=`netstat -rn | grep default | awk '{print $6}'`

echo "NIC: $nic1"
echo "IP: $ipaddress"

notify() {
  if [ $? -eq 0 ];
  then
            echo "OK"
  else
            echo "STOP: Something went wrong!"
            exit
  fi
}


create_jail(){
	echo "creating jail1"
  	ezjail-admin create jail1 $ipaddress > /dev/null 2>&1 && notify
        echo "copying resolv.conf file"
        cp /etc/resolv.conf /usr/jails/jail1/etc/resolv.conf && notify
        echo "remove /usr/bin symlink"
        rm /usr/jails/jail1/usr/bin && notify
        echo "copy the /usr/bin/ directory"
        cp -R -p /usr/jails/basejail/usr/bin /usr/jails/jail1/usr/ > /dev/null && notify
	echo "remove /usr/ports from jail"
	rm /usr/jails/jail1/usr/ports && notify
	echo "create directory to mount host's ports in"
	mkdir /usr/jails/jail1/usr/ports && notify
	echo "mounting host's ports"
	mount_nullfs -o ro /usr/ports/ /usr/jails/jail1/usr/ports && notify
	echo "creating ifconfig alias for $ipaddress"
	ifconfig $nic1 alias $ipaddress netmask 255.255.255.0 && notify
	echo "modifying /usr/local/etc/ezjail/jail1 to allow pinging" 
	awk '{ gsub("export jail_jail1_parameters=\"\"","export jail_jail1_parameters=\"allow.raw_sockets=1 allow.sysvipc=1\"" ) ; print }' /usr/local/etc/ezjail/jail1 > /usr/local/etc/ezjail/jail1-edited && notify
	rm /usr/local/etc/ezjail/jail1 && notify
	mv /usr/local/etc/ezjail/jail1-edited /usr/local/etc/ezjail/jail1 && notify
        echo "modifying SSHd configuration"
	awk '{ gsub("#ListenAddress 0.0.0.0","ListenAddress '$ipaddress'" ) ; print }' /usr/jails/jail1/etc/ssh/sshd_config > /usr/jails/jail1/etc/ssh/sshd_config_edited && notify
        rm /usr/jails/jail1/etc/ssh/sshd_config && notify
	awk '{ gsub("#PermitRootLogin no","PermitRootLogin yes"); print }' /usr/jails/jail1/etc/ssh/sshd_config_edited > /usr/jails/jail1/etc/ssh/sshd_config && notify
        echo "setting SSH to start" 
	echo 'sshd_enable="YES"' > /usr/jails/jail1/etc/rc.conf && notify
        echo 'creating directory for ssh'
	mkdir /usr/jails/jail1/root/.ssh && notify
        echo "copying ansible-master's key"
	cat ~/.ssh/id_rsa.pub >> /usr/jails/jail1/root/.ssh/authorized_keys && notify
	cat ~/.ssh/windows.pub >> /usr/jails/jail1/root/.ssh/authorized_keys && notify
        echo "setting correct SSH key permissions" 
        chmod 600 /usr/jails/jail1/root/.ssh/* && notify
	chmod 700 /usr/jails/jail1/root && notify
	echo "OK: jail ready to use - starting it up"
        ezjail-admin start jail1 && notify
	echo "Jail started - bootstrapping pkg manager"
}

delete_jail(){
	echo "stopping the jail"
	ezjail-admin stop jail1 && notify
	echo "unmount ports"
	umount /usr/jails/jail1/usr/ports && notify
	echo "deleting the jail" 
	ezjail-admin delete jail1 && notify
	echo "fixing permissions"
	chflags -R noschg /usr/jails/jail1 && notify
	echo "deleting old key from known_hosts"
        sed -i.'' '/'$ipaddress'/d' ~/.ssh/known_hosts && notify
	echo "deleting remaining files"
	rm -r -f /usr/jails/jail1 && notify
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
