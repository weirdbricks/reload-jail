#!/usr/bin/env sh
jail=$1
ipaddress=$2

if [ -z "$jail" ]
then
  echo "jail name not provided - stopping"
  exit
fi

if [ -z "$ipaddress" ]
then
  echo "ipaddress not provided - stopping"
  exit
fi  

echo "checking if jail: $jail is running.."
jail_status=`ezjail-admin list | grep $jail | grep -v grep | wc -l`
echo "the jail status is: $jail_status"

ipaddress=$2
nic1=`netstat -rn | grep default | awk '{print $6}'`

echo "NIC: $nic1"
echo "IP: $ipaddress"

notify() {
  if [ $? -eq 0 ];
  then
            echo $?
            echo "OK"
  else
            echo $?
            echo "STOP: Something went wrong!"
            exit
  fi
}


create_jail(){
	echo "creating jail: $jail"
  	ezjail-admin create $jail $ipaddress > /dev/null 2>&1 || notify
        echo "copying resolv.conf file"
        cp /etc/resolv.conf /usr/jails/$jail/etc/resolv.conf || notify
        echo "remove /usr/bin symlink"
        rm /usr/jails/$jail/usr/bin || notify
        echo "copy the /usr/bin/ directory"
        cp -R -p /usr/jails/basejail/usr/bin /usr/jails/$jail/usr/ > /dev/null || notify
	echo "remove /usr/ports from jail"
	rm /usr/jails/$jail/usr/ports || notify
	echo "create directory to mount host's ports in"
	mkdir /usr/jails/$jail/usr/ports || notify
	echo "mounting host's ports"
	mount_nullfs -o ro /usr/ports/ /usr/jails/$jail/usr/ports || notify
	echo "creating ifconfig alias for $ipaddress"
	ifconfig $nic1 alias $ipaddress netmask 255.255.255.0 || notify
	echo "modifying /usr/local/etc/ezjail/$jail to allow pinging" 
	awk '{ gsub("export jail_'$jail'_parameters=\"\"","export jail_'$jail'_parameters=\"allow.raw_sockets=1 allow.sysvipc=1\"" ) ; print }' /usr/local/etc/ezjail/$jail > /usr/local/etc/ezjail/$jail-edited || notify
	rm /usr/local/etc/ezjail/$jail || notify
	mv /usr/local/etc/ezjail/$jail-edited /usr/local/etc/ezjail/$jail || notify
        echo "modifying SSHd configuration"
	awk '{ gsub("#ListenAddress 0.0.0.0","ListenAddress '$ipaddress'" ) ; print }' /usr/jails/$jail/etc/ssh/sshd_config > /usr/jails/$jail/etc/ssh/sshd_config_edited || notify
        rm /usr/jails/$jail/etc/ssh/sshd_config || notify
	awk '{ gsub("#PermitRootLogin no","PermitRootLogin yes"); print }' /usr/jails/$jail/etc/ssh/sshd_config_edited > /usr/jails/$jail/etc/ssh/sshd_config || notify
        echo "setting SSH to start" 
	echo 'sshd_enable="YES"' > /usr/jails/$jail/etc/rc.conf || notify
        echo 'creating directory for ssh'
	mkdir /usr/jails/$jail/root/.ssh || notify
        echo "copying ansible-master's key"
	cat ~/.ssh/id_rsa.pub >> /usr/jails/$jail/root/.ssh/authorized_keys || notify
	cat ~/.ssh/windows.pub >> /usr/jails/$jail/root/.ssh/authorized_keys || notify
        echo "setting correct SSH key permissions" 
        chmod 600 /usr/jails/$jail/root/.ssh/* || notify
	chmod 700 /usr/jails/$jail/root || notify
	echo "OK: jail: $jail ready to use - starting it up"
        ezjail-admin start $jail || notify
	echo "Jail: $jail started - bootstrapping pkg manager"
}

delete_jail(){
	echo "stopping jail: $jail"
	ezjail-admin stop $jail || notify
        checkmount=`mount | grep $jail -c`
        echo "going to check for a mounted port tree: $checkmount"
	if [ $checkmount -eq 0 ];
        then
          echo "ports were not mounted for $jail"
        else
	  echo "unmount ports"
          umount /usr/jails/$jail/usr/ports || notify
        fi
	echo "deleting the jail" 
	ezjail-admin delete $jail || notify
	echo "fixing permissions"
	chflags -R noschg /usr/jails/$jail || notify
	echo "deleting old key from known_hosts"
        sed -i.'' '/'$ipaddress'/d' ~/.ssh/known_hosts || notify
	echo "deleting remaining files"
	rm -r -f /usr/jails/$jail || notify
	echo "jail completely deleted"

}

if [ $jail_status -eq 0 ];
then 
	echo "jail: $jail doesn't exist - getting it ready"
       create_jail
else
	echo "yup, jail: $jail is running - deleting"
	delete_jail
	echo "and rebuilding"
	create_jail
fi
