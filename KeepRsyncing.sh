#!/bin/bash
OLDIFS=$IFS
IFS=$'\n';

#---Init Variables---
is_done=false;
file_list="";
number_of_files=0;
argument_count=0;
#===Init Variables===

#----Defaults----
delete_after_transfer=true;
debug_level=0; 
inplace=true;
stats=true;
archive=true;
show_progress=true;
size_only=false;
key_file="";
#====Defaults=====


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

config_file_location=$(echo $HOME/KeepRsyncing/config.KeepRsyncing.txt);
Debug_Write 10 "Loading config file from: $config_file_location";
source $config_file_location;

function Arguments(){
	Debug_Write 0 "Reading Arguments"
	while [[ $# -gt 1 ]]
	do
	local key="$1"
		case $key in
			-dir)
			Debug_Write 0 "Dir Location: $2"
			dir_location="$2"
			argument_count=$((argument_count+2));
			shift # past argument
			;;
			-username)
			Debug_Write 0 "Rsync User: $2"
			username="$2";
			argument_count=$((argument_count+2));
			shift # past argument
			;;
			-server_address)
			Debug_Write 0 "Remote Server Address: $2"
			server_address="$2";
			argument_count=$((argument_count+2));
			shift # past argument
			;;
			-upload_location)
			Debug_Write 0 "Remote Location: $2"
			upload_location="$2";
			argument_count=$((argument_count+2));
			shift # past argument
			;;
			-debug_level)
			Debug_Write 0 "Debug Level: $2"
			debug_level="$2";
			argument_count=$((argument_count+2));
			shift # past argument
			;;
			-key_file)
			Debug_Write 0 "Key File: $2"
			key_file="$2";
			argument_count=$((argument_count+2));
			shift # past argument
			;;
                        -upload_speed)
                        Debug_Write 0 "Setting Upload Speed: $2"
                        upload_speed="$2";
                        argument_count=$((argument_count+2));
                        shift # past argument
                        ;;
			-delete)
        	        Debug_Write 0 "Deleting After Transfer"
			delete_after_transfer=true;
        	        argument_count=$((argument_count+1));
              		;;
                        -keep)
                        Debug_Write 0 "Keeping After Transfer"
                        delete_after_transfer=false;
                        argument_count=$((argument_count+1));
                        ;;
                        -no_stats)
                        Debug_Write 0 "Not showing stats"
                        show_stats=false;
                        argument_count=$((argument_count+1));
                        ;;
                        -no_archive)
                        Debug_Write 0 "Disabling Archive"
                        archive=false;
                        argument_count=$((argument_count+1));
                        ;;
			--default)
			DEFAULT=YES
			;;
			*)
				# unknown option
			;;
		esac
	shift # past argument or value
	done
	file_list="${@:$(($argument_count+1))}";
	number_of_files=$(($# - ($argument_count)));
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
function Combine_Command_String(){
echo out="$1 $2";
}
function Build_Rsync(){
	#rsync --rsh='/tmp/pv-wrapper ssh' --inplace -arzvvP --remove-source-files "$1" $username@$server_address:~/;
	local rsync_command=""
	Debug_Write 0 "Building Command";
	rsync_command=$(Combine_Command_String "$rsync_command" "rsync");
	rsync_command=$(Combine_Command_String "$rsync_command" "-vvrih");
	if $size_only; then
		Debug_Write 0 "Adding Size only"
		rsync_command=$(Combine_Command_String "$rsync_command" "--size-only");
	fi
	if $show_progress; then
		Debug_Write 0 "Adding progress information";
		rsync_command=$(Combine_Command_String "$rsync_command" "-P");
	fi
        if $archive; then
		Debug_Write 0 "Enabling Archiving";
        	rsync_command=$(Combine_Command_String "$rsync_command" "-a");
        fi
	if $stats; then
		Debug_Write 0 "Enabling Stats";
        	rsync_command=$(Combine_Command_String "$rsync_command" "--stats");
        fi
	if $inplace; then
		Debug_Write 0 "Enabling inplace uploads";
        	rsync_command=$(Combine_Command_String "$rsync_command" "--inplace");
        fi
	if $delete_after_transfer; then
		Debug_Write 0 "Deleting files after transfer";
		rsync_command=$(Combine_Command_String "$rsync_command" "--remove-source-files");
	fi
	if [[ $upload_speed -gt 0 ]]; then
		Debug_Write 0 "Setting upload speed to $upload_speed";
		rsync_command=$(Combine_Command_String "$rsync_command" "--bwlimit=$upload_speed");
	fi
	if [ ! -z $key_file ]
		Debug_Write 0 "Applying KeyFile $key_file";
		rsync_command=$(Combine_Command_String "$rsync_command" "-e 'ssh -i $key_file'");
	fi
	Debug_Write 0 "Inserting file list: $file_list"
	rsync_command=$(Combine_Command_String "$rsync_command" "$file_list");
	Debug_Write 0 "Adding destination information";
	rsync_command=$(Combine_Command_String "$rsync_command" "$username@$server_address:\"$upload_location\"");
	echo "$rsync_command";
}

function Old_Transfer(){
Debug_Write 1 "Looping through arguments to transfer: \"$#\"";
while [[ $# -gt 0 ]];
do
        Debug_Write 1 "Testing if $1 file is not missing";
        while [ -a $1 ];
        do
                Debug_Write 1 "$1 is not missing. Starting rsync";
                #rsync --rsh='/tmp/pv-wrapper ssh' --inplace -arzvvP --remove-source-files "$1" $username@$server_address:~/;
                rsync_command="rsync -avvrPih --stats --inplace ";
                rsync_command="--remove-source-files ";
                rsync_command=
                rsync -avvrPih --stats --inplace --remove-source-files --bwlimit=$upload_speed "$1" $username@$server_address:"$upload_location" ;
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

function MAIN(){
	Arguments "$@";
	file_list="${@:$argument_count}";
	Debug_Write 1 "Comparing Size of job Vs space on server";
	local l_totalsize=$(GetTotalSize "$file_list");
	local l_freespace=$(GetFreeSpace);
	if [[ $l_totalsize -gt $l_freespace ]];
	then
		Debug_Write 100 "NOT ENOUGH SPACE!!!";
		sleep 10;
	else
		local freespaceratio=$(( $l_freespace / $l_totalsize ));
		Debug_Write 100 "Looks like we have ${freespaceratio}x of space needed";
	fi
	while ! is_done;
	do
		local rsync_command=$(Build_Rsync);
		Debug_Write 0 "Running Command! $rsync_command"
		eval $(rsync_command);
		if [[ $? -eq 0 ]];
		then
			Debug_Write 10 "Uploading of $file_list seems to be sucessful"
			is_done=true;
		else
			Debug_Write 100 "Upload FAILED, Retrying in 10 seconds;
		fi
	done
}

MAIN "$@";

echo "-=-=-=-=-=-=DONE=-=-=-=-=-=-=-=-";
IFS=$OLDIFS
exit 0
