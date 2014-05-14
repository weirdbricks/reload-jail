#!/usr/bin/env sh
jail=$1
ipaddress=`ezjail-admin list | grep $jail | awk '{print $3}'`

if [ -z "$jail" ]
then
  echo "jail name not provided - stopping"
  exit
fi

echo "checking if jail: $jail is running.."
jail_status=`ezjail-admin list | grep $jail | grep -v grep | wc -l`
echo "the jail status is: $jail_status"


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
	echo "jail: $jail doesn't exist"
#       create_jail
	exit
else
	echo "yup, jail: $jail is running - deleting"
	delete_jail
#	echo "and rebuilding"
#	create_jail
fi
