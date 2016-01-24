#!/bin/bash

if [ ! -z "$1" ]; then
	source ./$1
fi

# Expected image size in MB
IMAGE_SIZE_M=28

# In minutes
MAXIMUM_WAITING_TIME=55
MAXIMUM_WAITING_TIME_S=$[MAXIMUM_WAITING_TIME*60]
echo "Welcome to the NQB scan program."

# Directory
if [ -z "$DIRECTORY" ]; then
	read -p "Please enter directory:" DIRECTORY
fi

# check if directory exists
while [ ! -d $DIRECTORY ]; do
	read -p "Directory $DIRECTORY doesn't exist. Please try again:" DIRECTORY
done

# Wait time
if [ -z "$WAIT_TIME" ]; then
	read -p "The wanted waiting time (in m):" WAIT_TIME
fi

# Validate wait time
while [[ $WAIT_TIME == *[!0-9]* ]]; do
    echo "'$WAIT_TIME' has a non-digit somewhere in it,please enter it again."
    read -p "The wanted waiting time:" WAIT_TIME
done

# Interval
if [ -z "$INTERVAL" ]; then
	read -p "The wanted interval time between two scans (in m):" INTERVAL
fi

# Validate interval
while [[ $INTERVAL == *[!0-9]* ]]; do
    echo "'$INTERVAL' has a non-digit somewhere in it,please enter it again."
    read -p "The wanted interval:" INTERVAL
done

# Number of scans
if [ -z "$NUMBER_OF_SCANS" ]; then
	read -p "The wanted number of scans:" NUMBER_OF_SCANS
fi

# Validate number of scans
while [[ $NUMBER_OF_SCANS == *[!0-9]* ]]; do
    echo "'$NUMBER_OF_SCANS' has a non-digit somewhere in it,please enter it again."
    read -p "The wanted number of scans:" NUMBER_OF_SCANS
done

# File prefix
if [ -z "$FILE_PREFIX" ]; then
	read -p "Please enter a prefix for the scan files:" FILE_PREFIX
fi

# Scanners
echo "the available scanners are (please wait):"
list=$(scanimage -f ' %d ')

# take only the named scanners
i=0
for scanner in $list
do
	 if [[ $scanner == *NQBSCANNER* ]]
	 then
		array_scanners[$i]=$scanner
		echo "$i) $scanner" 
		i=$[i+1]
	 fi
done

if [ "$SCANNERS" == "ALL" ]; then
	scanners_idx=0
	for scanner in ${array_scanners[@]}
	do
		SCANNERS[$scanners_idx]=${array_scanners[$scanners_idx]}
		curr_s_name=$(echo ${scanner} | sed -r "s/.*NQBSCANNER//")
		SCANNERS_ID[$scanners_idx]=$curr_s_name
		echo "you chose scanner: '"${scanner}$"'. Name will be '$curr_s_name'"
		scanners_idx=$[scanners_idx+1]
	done
else
	read -p "Type the wanted scanners number (to finish press q):" curr
	scanners_idx=0
	while [ $curr != 'q' ]; do

		if [[ $curr == *[!0-9]* ]]; then
		    echo "'$curr' has a non-digit somewhere in it,please enter it again."
		elif [ $curr -gt $i ]; then
		    echo "scanner no. $curr is not in the list."
		else
		    SCANNERS[$scanners_idx]=${array_scanners[$curr]}
		    curr_s_name=$(echo ${array_scanners[$curr]} | sed -r "s/.*NQBSCANNER//")
		    SCANNERS_ID[$scanners_idx]=$curr_s_name
		    echo "you chose scanner: '"${array_scanners[$curr]}$"'. Name will be '$curr_s_name'"
		    scanners_idx=$[scanners_idx+1]
		fi

		read -p "Type the wanted scanners number (to finish press q):" curr
	done
fi

# Calculate the expected size on disk in MB needed for the process
# This is equal to image size * number of scans * number of scanners
echo ""
expectedSize=$[IMAGE_SIZE_M*scanners_idx*NUMBER_OF_SCANS]
echo "Expected size on disk for this proccess is $expectedSize mb"
avialableSize=$(df -m / | tail -1 | awk '{print $4}')
echo "available size on disk is $avialableSize mb"
proceedFlag='y'
if [ $expectedSize -gt $avialableSize ]; then
	read -p "Important! Not enough space available on disk. Do you want to proceed? y - yes, n - no : " proceedFlag
fi

if [ $proceedFlag == 'n' ]; then
	echo "No scanning, bye."
	exit
fi

if [ -z "$MAILS" ]; then
	i=0
	read -p "Please enter a mail to send errors to :" mail

	while [ $mail != 'q' ]; do
		MAILS[$i]=$mail
		i=$[i+1]
		read -p "Please enter another mail or press q to finish :" mail
	done
fi

echo ""
echo "================================================================"
echo "Summary"
echo "================================================================"
echo "Scanning directory is $DIRECTORY"
echo "Waiting time after background scanning is $WAIT_TIME m"
echo "Interval time between two scans is $INTERVAL m"
echo "The wanted number of scans is $NUMBER_OF_SCANS"
echo "The file prefix is '$FILE_PREFIX'"
start_scanning=$(date --date "now +$WAIT_TIME mins" +"%H:%M %d-%m-%Y")
echo "Scannig start at ~$start_scanning" 
minutes_to_end=$[WAIT_TIME+INTERVAL*NUMBER_OF_SCANS]
end_scanning=$(date --date "now +$minutes_to_end mins" +"%H:%M %d-%m-%Y")
echo "Proccess will end at ~$end_scanning" 
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Chosen scanners are:"
tLen=${#SCANNERS[@]}
for (( i=0;i<$tLen;++i)); do
	echo "scanner ${SCANNERS[$i]}, named '${SCANNERS_ID[$i]}'"
done
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Mails are:"
mailLen=${#MAILS[@]}
for (( i=0;i<$mailLen;++i)); do
	echo "'"${MAILS[$i]}$"'"
done
echo "================================================================"

read -p "Press s to start scanning or q to finish:" start

while [ $start != 'q' ] && [ $start != 's' ]; do
	read -p "Press s to start scanning or q to finish:" start
done

echo ""

if [ $start == 'q' ]; then
	echo "No scanning, bye."
	exit
fi

echo "Start scanning, good luck!"

cd $DIRECTORY

# Create the log's file name
log_name="run_"$FILE_PREFIX$(date +"%Y%m%d_%H%M")$".log"

# validate the scanners names
list=$(scanimage -f ' %d ')
valid=true
for (( i=0; i<${tLen}; i++))
do
	currPattern=$' '${SCANNERS[$i]}$' '
	if [[ $list != *$currPattern* ]]
	then
		echo $(date +"%Y%m%d_%H%M")$" - Error - Scanner ${SCANNERS[$i]} doesn't exist." >> $log_name
		valid=false
		break
	fi
done


if $valid
then
	# Print summary to log file
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"Starting." >> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"================================================================">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"Summary">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"================================================================">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"Scanning directory is $DIRECTORY">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"Waiting time after background scanning is $WAIT_TIME m">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"Interval time between two scans is $INTERVAL m">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"The wanted number of scans is $NUMBER_OF_SCANS">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"The file prefix is '$FILE_PREFIX'">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"Chosen scanners are:">> $log_name
	tLen=${#SCANNERS[@]}
	for (( i=0;i<$tLen;++i)); do
		echo $(date +"%Y/%m/%d %H:%M:%S - ")$"scanner ${SCANNERS[$i]}, named '${SCANNERS_ID[$i]}'">> $log_name
	done
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~">> $log_name
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"Mails are:">> $log_name
	mailLen=${#MAILS[@]}
	for (( i=0;i<$mailLen;++i)); do
		echo $(date +"%Y/%m/%d %H:%M:%S - ")$"'"${MAILS[$i]}$"'">> $log_name
	done
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$"================================================================">> $log_name

	echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Scanning backgrounds." >> $log_name

	# Scan background for each scanner in the list
	beforeBack=$(date +%s)

	for (( i=0; i<${tLen}; i++));
	do
		curr_name=${SCANNERS[$i]}
		curr_id=${SCANNERS_ID[$i]}

		# Build file name  
		file_name=$FILE_PREFIX$"_"$curr_id$"_"$(date +"%Y%m%d_%H%M")$".tif"

		# Scan
		echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Before scanning background for "$curr_name >> $log_name

		# scan using clear calibration for cannon scanners
		if [[ $curr_name == *genesys:libusb* ]]
		then
			scan_result=$(scanimage -d $curr_name --resolution=300 --format=tiff --mode=Color --clear-calibration 2>&1 > $file_name )
		else
			scan_result=$(scanimage -d $curr_name --resolution=300 --format=tiff --mode=Color 2>&1 > $file_name )
		fi

		# Check if stderr returned something
		if [ ! -z "$scan_result" ]; then

			# Write to logfile
			echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Error: "$scan_result >> $log_name

			# Send mails
			for (( k=0; k<${mailLen}; k++));
			do
				curr_mail=${MAILS[$k]}
				message="To: $curr_mail \nFrom:$curr_mail\nSubject:NQB - Scanning error\n\n"$scan_result$"\n"
				echo -e $message | ssmtp -t 
			done
		fi
		echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Background scanned for "$curr_name >> $log_name
	done

	afterBack=$(date +%s)

	echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Backgrounds scanned" >> $log_name

	backgroundTime=$(($afterBack-$beforeBack))

	seconds=$[WAIT_TIME*60]
	waitingleft=$[$seconds-$backgroundTime]

	while [ $waitingleft -gt 0 ]; do
		
		# Maximum witing time 
		curr_waiting=$waitingleft
		if [ $waitingleft -gt $MAXIMUM_WAITING_TIME_S ]; then
			curr_waiting=$MAXIMUM_WAITING_TIME_S
		fi
		waitingleft=$[waitingleft-curr_waiting]
		echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Sleeping for $curr_waiting s" >> $log_name
		sleep $curr_waiting
		scanimage -L
	done

	seconds=$[INTERVAL*60]
	echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Scanning $NUMBER_OF_SCANS scans, interval between is $INTERVAL m" >> $log_name
	for ((i=1;i<=$NUMBER_OF_SCANS;++i));
	do
		beforeIt=$(date +%s)
		for (( k=0; k<${tLen}; k++));
		do
			curr_name=${SCANNERS[$k]}
			curr_id=${SCANNERS_ID[$k]}	

			# Build file name  
			file_name=$FILE_PREFIX$"_"$curr_id$"_"$(date +"%Y%m%d_%H%M")$".tif"

			# Scan
			echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Before scan no. $i/$NUMBER_OF_SCANS for $curr_name" >> $log_name	
			# scan using clear calibration for cannon scanners
			if [[ $curr_name == *genesys:libusb* ]]
			then
				scan_result=$(scanimage -d $curr_name --resolution=300 --format=tiff --mode=Color --clear-calibration 2>&1 > $file_name )
			else
				scan_result=$(scanimage -d $curr_name --resolution=300 --format=tiff --mode=Color 2>&1 > $file_name )
			fi

			# Check if stderr returned something
			if [ ! -z "$scan_result" ]; then
				# Write to logfile
				echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Error: "$scan_result >> $log_name

				# Send mails
				for (( j=0; j<${mailLen}; j++));
				do
					curr_mail=${MAILS[$j]}
					message="To: $curr_mail \nFrom:$curr_mail\nSubject:NQB - Scanning error\n\n"$scan_result$"\n"
					echo -e $message | ssmtp -t 
				done
			fi
			echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - After scan no. $i/$NUMBER_OF_SCANS  for "$curr_name  >> $log_name
		done

		afterIt=$(date +%s)
		iterationTime=$(($afterIt-$beforeIt))
		iterationleft=$[$seconds-$iterationTime]

#
		waitingleft=$iterationleft

		while [ $waitingleft -gt 0 ]; do
		
			# Maximum witing time 
			curr_waiting=$waitingleft
			if [ $waitingleft -gt $MAXIMUM_WAITING_TIME_S ]; then
				curr_waiting=$MAXIMUM_WAITING_TIME_S
			fi
			waitingleft=$[waitingleft-curr_waiting]
			echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Sleeping for $curr_waiting s" >> $log_name
			sleep $curr_waiting
			scanimage -L
		done
#
#		if [ $iterationleft -gt 0 ]; then
#			echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Sleeping for $iterationleft s" >> $log_name
#			sleep $iterationleft
#		fi
		echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - finished $i scanning" >> $log_name
	done
fi

echo $(date +"%Y/%m/%d %H:%M:%S - ")$" - Done." >> $log_name
