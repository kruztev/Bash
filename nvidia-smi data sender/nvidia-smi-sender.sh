#!/bin/bash

# Initialize log
log=/home/krustev-a/nvidia-smi-sender.log #/var/log/nvidia-smi-sender.log
date_format="%F %T"

if [ ! -f $log ]; then
	echo "$( date +"$date_format" ) Log created" > $log
fi

# Check if nvidia-smi command is installed
which nvidia-smi > /dev/zero
if [ $? -ne 0 ]; then
	echo "nvidia-smi command is nonexistent or not executable" 1>&2
	echo "$( date +"$date_format" ) Command nvidia-smi is nonexistent or not executable" >> $log
	exit 1
fi

# collect_data function collects data about GPU utilization, GPU memory, CPU utilization and memory. It also formats the data so that it is easier to read.
function collect_data {

        # GPU id is passed as an argument

        # Collect data about GPU utilization
        gpu_util_unformatted=$( nvidia-smi -q -i $1 -d "UTILIZATION" | grep Utilization -A 1 | awk '{ print $3 }' | head -n 2 | tail -n 1 )

        gpu_utilization="${gpu_util_unformatted}%"

        # Collect data about GPU memory
        gpu_used_mem=$( nvidia-smi -q -i $1 -d "MEMORY" | grep "FB Memory" -A 2 | tail -n 2 | awk '{ print $3 }' | tail -n 1 )

        gpu_total_mem=$( nvidia-smi -q -i $1 -d "MEMORY" | grep "FB Memory" -A 2 | tail -n 2 | awk '{ print $3 }' | head -n 1 )

        gpu_memory="$gpu_used_mem MiB / $gpu_total_mem MiB"

        # Collect data baout CPU utilization (Subtract idle value from 100)
        cpu_util_unformatted=$( awk "BEGIN { printf 100 - $( top -n 1 | grep %Cpu | awk '{print $8}' ) }" )

        cpu_utilization="${cpu_util_unformatted}%"


        # Collect data about memory
        used_mem=$( top -n 1 | grep "MiB Mem" | awk '{ print $8}' )

        total_mem=$( top -n 1 | grep "MiB Mem" | awk '{ print $4}' )

        memory="$used_mem MiB / $total_mem MiB"
}

# write_data function writes the collected data to the output file
function write_data {

	# GPU id is passed as an argument

        echo "\"GPU $1\": {" >> $output_file
        echo "\"timestamp\": \"$( date +"$date_format" ) \"," >> $output_file
        echo "\"GPU Utilization\": \"${gpu_utilization}\"," >> $output_file
        echo "\"GPU Memory\": \"$gpu_memory\"," >> $output_file
        echo "\"CPU Utilization\": \"$cpu_utilization\"," >> $output_file
        echo "\"Memory\": \"$memory\"" >> $output_file
}


# Get the count of GPUs
gpu_count=$( nvidia-smi -L | wc -l )


current_date=$( date +%F )
output_file="/home/krustev-a/nvidia-smi/output-files/$( date +"%F").json"
touch $output_file

# Variables which will be used in the collect_data function and write_data function
gpu_utilization=0
gpu_memory=0
cpu_utilization=0
memory=0

# gpu_max_id will be used in the for loop condition. It represents the max value for a  gpu id
gpu_max_id=$(($gpu_count - 1))

# A number which represents the seconds that the script will wait before collecting new data
collect_data_interval=5

while [ true ]; do 

	# echo "{" >> $output_file
	# Go through all GPUs
	for ((gpu_id = 0; gpu_id <= $gpu_max_id; ++gpu_id)); do
		
		collect_data $gpu_id
		write_data $gpu_id
		
		# if [ $gpu_id -ne $gpu_max_id ]; then
			echo "}," >> $output_file
		#else
		#	echo "}" >> $output_file
		#fi
	done
	sleep $collect_data_interval
	# echo "}" >> $output_file
	if [ $( date +%F ) != $current_date ]; then
		output_file="/home/krustev-a/nvidia-smi/$( date +"%F").json"
		echo "$( date +"$date_format" ) Date changed. Output file \"$output_file\" should be created" >> $log
		touch $output_file
		echo "$( date +"$date_format" ) Output file \"$output_file\" created" >> $log
		# echo "{" >> $output_file
	fi
done

