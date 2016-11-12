#!/bin/bash
OLDIFS=$IFS
IFS=$'\n';
debug_level=0;
username="root";
server_address="2.p0p.us";

function Debug_Write(){
	#Debug_Write 0 "message"
	local l_set_debug_level=$1;
	if [ $debug_level -le $l_set_debug_level ]; then
		local l_from_function=${FUNCNAME[1]};
		local l_debug_message=$2;
		local time=`date +"%T"`;
		echo -e "DEBUG[$l_set_debug_level] - $time: $l_from_function - $l_debug_message" >> /dev/tty;
	fi
}

function GetTotalSize(){
	Debug_Write 3 "Getting total size"
Debug_Write 0 "Running Disk Used command";
local totalsize=$(du -c $* | tail -n 1 | tr -s \" \" | cut -f1)
Debug_Write 0 "totalsize is $totalsize";
echo "$totalsize";
}

function GetFreeSpace(){
Debug_Write 3 "Getting Free Space";
local freespace_from_ssh=$(ssh $username@$server_address df -B1 | grep /dev/simfs | head -n 1 | tr -s " " | cut -f4 -d " ");
Debug_Write 0 "freespace_from_ssh is $freespace_from_ssh";
echo "$freespace_from_ssh"
}

function MAIN(){
Debug_Write 1 "Comparing Size of job Vs space on server";
local l_totalsize=$(GetTotalSize "$@");
local l_freespace=$(GetFreeSpace);
if [[ $l_totalsize -gt $l_freespace ]];
then
Debug_Write 100 "NOT ENOUGH SPACE!!!";
else

local freespaceratio=$(( $l_freespace / $l_totalsize ));

Debug_Write 100 "Looks like we have $freespaceratio\x of space needed";

fi

Debug_Write 1 "Looping through arguments to transfer: \"$#\"";
while [[ $# -gt 0 ]];
do
	Debug_Write 1 "Testing if $1 file is not missing";
	while [ -a $1 ];
	do
		Debug_Write 1 "$1 is not missing. Starting rsync";
		#rsync --rsh='/tmp/pv-wrapper ssh' --inplace -arzvvP --remove-source-files "$1" $username@$server_address:~/;
		rsync -avvrPih --stats --inplace --remove-source-files --bwlimit=100 "$1" $username@$server_address:~/ ;
		sleep 2;
	done

	Debug_Write 1 "Testing if file $1 is gone. If it is, a likely sucessful transfer";
	if [ ! -a $1 ];
	then
		Debug_Write 1 "$1 is missing, Shifting";
		shift;
	fi
done


}

MAIN "$@";

echo "-=-=-=-=-=-=DONE=-=-=-=-=-=-=-=-";
IFS=$OLDIFS
exit 0
