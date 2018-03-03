#!/bin/sh
#
#Author: Avtar Singh, avtarsingh127@gmail.com
#Version: 0.2
#Prequesties: 
#########Ubuntu#########
#	sudo apt-get install percona-xtrabackup

#########REDHAT or CensOS #########
# yum install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
# yum install percona-xtrabackup-24
# yum install qpress
#####  SETTINGS  #####

# CREATE USER 'bkpuser'@'localhost' IDENTIFIED BY 'gEt4jhjd(fdg!5g5afD';
# GRANT RELOAD,PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'bkpuser'@'localhost';
# Flush privileges;


DB=testdb              #can give multiple DB names comma separated
# What day to make the full weekly backup? Monday=1, Tuesday=2, .., Sunday=7
WEEKLYBACKUPDAY=7
WEEKLYBACKUPHOUR=01
# What time (hour) daily backup will be taken
# daily backup will be incremental backup from last full backup
# on first day, backup will be small because it will be contain one day data, but will increase every day

# Incremental backup frequency depends upon the cron job timing
# Incremental backup will be very fast, bacuase it will only take backup from last incremental backup
# For example if cronjob is setup after 1 hour for this script, Incremental backup will always contain last 1 hour changes only
# mkdir /var/log/mysql/backup -p
# Backup directory
DIR=/mnt/dbbackup
# Configuration file with username and password
DEFAULTS=/etc/mysql_backup_server.cnf
# Log Files
BACKUPLOG=$DIR/log/innobackupex.log
SCRIPTLOG=/var/log/mysql/backup/log_`date +%Y-%m-%d\_%H-%M-%S`.log

DEBUG=0   # Print Debug information on screen, 0 to unset
#Full backup copies to be retained, will delete older than this automatically
backup_copies=1

### END SETTINGS ###


### DO NOT MODIFY ###
# Parameters used below - INFO
DAYOFWEEK=`date +%u`
HOUROFDAY=`date +%H`
DATELONG=`date +%Y-%m-%d\_%H-%M-%S`
DATESHORT=`date +%Y-%m-%d`

debug_info()
{
	if [ $DEBUG -eq 1 ]; then
		echo "DEBUG - $1" | tee -a $SCRIPTLOG
	else 
		echo "$1">>$SCRIPTLOG
	fi
	
}

# DEBUG
debug_info "DAYOFWEEK=$DAYOFWEEK"
debug_info "HOUROFDAY=$HOUROFDAY"
debug_info "DATELONG=$DATELONG"
debug_info "DATESHORT=$DATESHORT"

checkdbconnection()
	{
		# Check if we can connect to the database
		echo "\q" | mysql --defaults-extra-file=$DEFAULTS 2>>$SCRIPTLOG
		if [ $? -ne 0 ]; then
		    echo "Error connecting to the database using $DEFAULTS, exiting..." | tee -a $SCRIPTLOG
		    exit 1
		else
			debug_info "DB Connection Successful" 
		fi
	}


make_dir()
	{
		debug_info "Going to check and create required directories"
		# Check and Create the directories
		if [ ! -e "$DIR/full" ]; then
			debug_info "Creating directory $DIR/full"
			mkdir -p "$DIR/full"
		else
			debug_info "Directory $DIR/full exists"
		fi

		if [ ! -e "$DIR/daily" ]; then
			debug_info "Creating directory $DIR/daily"
			mkdir -p "$DIR/daily"
		else
			debug_info "Directory $DIR/daily exists"
		fi

		if [ ! -e "$DIR/log" ]; then
			debug_info "Creating directory $DIR/daily"
			mkdir -p "$DIR/log"
		else
			debug_info "Directory $DIR/log exists"
		fi
	}

# Will create full backup if called without checking anything for that date and time
full_backup()
{

	# Create a new backup for the day, week or month
	debug_info "Creating full backup for $DATELONG"
	innobackupex --defaults-extra-file=$DEFAULTS  --databases=$DB --galera-info --compress $DIR/$TYPE 2>>$BACKUPLOG
	# Print the status
	tail -n 3 $BACKUPLOG | tee -a $SCRIPTLOG
}

# Will create incremental backup in target directory ($1), based on ($2) without checking anything
incr_backup()
{	
	debug_info "Creating incremental backup"
	debug_info "LASTBACKUPPATH=$2"
	debug_info "TARGETDIR=$1"
	innobackupex --defaults-extra-file=$DEFAULTS  --databases=$DB --galera-info --compress --incremental $1 --incremental-basedir=$2 2>> $BACKUPLOG
            # Print the status
	tail -n 3 $BACKUPLOG | tee -a $SCRIPTLOG

}


#This function will setup the initial type of backup based on settings of dates and hour
backup_type()
{
	debug_info "Checking Day and hour to decide if it is full backup or incremental"
	# If weekly, set TYPE=weekly
	if [ $WEEKLYBACKUPDAY -eq $DAYOFWEEK -a $WEEKLYBACKUPHOUR = $HOUROFDAY ]; then
	    debug_info "Do Full backup: $DATELONG"
	    TYPE=full
	else
	    debug_info "Do Daily Incremental backup: $DATELONG"
	    TYPE=daily
	fi

}



find_base_and_target()
{
	# Check if we have an old backup for this day
	LASTBACKUPPATH=`ls -d $DIR/$TYPE/* | grep $DATESHORT | sort | tail -n 1` 2>/dev/null
	#debug_info "1. LASTBACKUPPATH=$LASTBACKUPPATH"
	if [ "x$LASTBACKUPPATH" != 'x' ]; then
		debug_info "We have found the latest backup for today $LASTBACKUPPATH, we need to fetch latest incremental backup inside this directory"
		mkdir -p $LASTBACKUPPATH/incr

		LASTINCPATH=`ls -d $LASTBACKUPPATH/incr/*/ | grep $DATESHORT | sort | tail -n 1` 2>/dev/null
		TARGETDIR=$LASTBACKUPPATH/incr  # incremental backup will be inside today's backup folder
		#debug_info "1. TARGETDIR=$TARGETDIR"
		if [ "x$LASTINCPATH" != 'x' ]; then
			debug_info "Incremental backup found for today: $LASTINCPATH, this will be used as base"
			LASTBACKUPPATH=$LASTINCPATH
			
		else
			debug_info "No incrmental backup inside today's backup, so parent backup will be used as base database for incr backup"
		fi
	else
		debug_info "No backup found for today: $DATESHORT"
		TARGETDIR=$DIR/$TYPE/   #No backup for today, if last full not found, this variable will not be used, so safe to set now
		TYPE=full
		debug_info "Need to use last full backup as base"
		#No backup found for today, need to give last full backup as base 
		#debug_info "1. DATESHORT=$DATESHORT"
		LASTBACKUPPATH=`ls -d $DIR/$TYPE/* | sort | tail -n 1` 2>/dev/null
		#debug_info "2. LASTBACKUPPATH=$LASTBACKUPPATH"
		#debug_info "2. TARGETDIR=$TARGETDIR"
		if [ "x$LASTBACKUPPATH" != 'x' ]; then
			debug_info "Found last full backup and it will be used as base: $LASTBACKUPPATH"
			TYPE=daily
			
			
		else
			debug_info "No full backup found, Full backup is needed"
		fi
		
	fi
}

decider()
{
	
	if [ "x$TYPE" = 'xfull' ]; then
		debug_info "We are going to do a $TYPE backup"
		full_backup

	elif [ "x$TYPE" = 'xdaily' ]; then
		debug_info "We are going to do a $TYPE backup"
		find_base_and_target
		#debug_info "LASTBACKUPPATH=$LASTBACKUPPATH"
		if [ "x$LASTBACKUPPATH" = 'x' ]; then
			debug_info "Full Backup needed"
			full_backup
		else
			#debug_info "Doing incremental backup"
			#debug_info "3. LASTBACKUPPATH=$LASTBACKUPPATH"
			#debug_info "3. TARGETDIR=$TARGETDIR"
			incr_backup $TARGETDIR $LASTBACKUPPATH
		fi	
		
	
	else 
		debug_info "There is no backup scheduled for this time: $DATELONG"
		exit 0
	fi
}


cleanup_older()
{
	 # Clean up older backups
	debug_info "Going to delete the following full backups"
	DEL=`ls -d $DIR/full/*/ 2>/dev/null | sort -r | awk "NR>$backup_copies {print $1}"| wc -l`
	if [ 'x0' != "x$DEL" ]; then 
		ls -d $DIR/full/*/ 2>/dev/null | sort -r | awk "NR>$backup_copies {print $1}" | tee -a $SCRIPTLOG
		ls -d $DIR/full/*/ 2>/dev/null | sort -r | awk "NR>$backup_copies {print $1}" | xargs rm -r 2>/dev/null

		OLDESTFULL=`ls -d $DIR/full/*/ | sort | head -n 1`  #get the oldest full backup after delete
		debug_info "Oldest full backup after delete: $OLDESTFULL"

		if [ 'x' != "x$OLDESTFULL" ]; then #if there is any full backup left
			#get the short date from oldest full backup
			OLDESTFULLDATE=`echo $OLDESTFULL | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}'`
			debug_info "Short date from the oldest full backup: $OLDESTFULLDATE"
			OLDESTFULLDATE=`date -d $OLDESTFULLDATE +%s`   #Convert into Unix Timestamp for comparison
			debug_info "Loop through daily folder and get short date from each backup"
			#Delete all those which has lesser date then $OLDESTFULLDATE
			for dir in $DIR/daily/*/
			do
				DAILYBACKUPDATE=`echo $dir | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}'`
				if [ 'x' != "x$DAILYBACKUPDATE" ]; then
				
					DAILYBACKUPDATE=`date -d $DAILYBACKUPDATE +%s`  #Convert into Unix Timestamp for comparison
					if [ $OLDESTFULLDATE -gt $DAILYBACKUPDATE ]; then 
						#backup is older than oldest full backup date
						debug_info "deleting $dir"
						rm -r $dir
					fi
				fi
			done
		fi
	else 
		debug_info "Nothing to delete"
	fi
}

# In this function we are checking if a shared drive is mounted or not.
# if not mounted we try to mount it before taking backup
# Example here is for cifs share
prebackup()
	{
		is_prebackup=0
		if mountpoint -q /mnt/dbbackup 
		then
	   		debug_info "Shared drive is already mounted"
		else
	   		debug_info "Shared drive is not mounted, trying mounting..."
	   		mount -t cifs //<IP Address>/<sharedFolderName> /mnt/dbbackup -o username=<username>,password=<"password">,domain=nixcraft
	   		if [ $? -eq 0]; then
	   			debug_info "Shared drive mounted succesfully"
			else
			  debug_info "Mount Failed :( "
			  is_prebackup=1
			fi
		fi
	}

send_failed_email()
	{
		successful=$(tail -n 1 /mnt/dbbackup/log/innobackupex.log | grep -i "completed OK" | wc -l)
		if [ $successful -ne 1 ]
		then
			MAILTO="asingh@wellshade.com"
			SUBJECT="Subject: Database backup failed"
			BODY="Database backup failed on server <server name>, please check $BACKUPLOG and $SCRIPTLOG for more details." 
			
			echo -en "$SUBJECT\n\n$BODY">/tmp/failed_`date +%Y-%m-%d\_%H-%M-%S`.log
			sendmail $MAILTO</tmp/failed_$SCRIPTLOG

		fi
	}
##### SCRIPT START POINT ####
is_prebackup=0
prebackup
if [ $is_prebackup -eq 0 ]
	then
		checkdbconnection
		make_dir
		backup_type
		decider
		send_failed_email
#post_backup
#cleanup_older
		debug_info "Backup is completed, please check $BACKUPLOG and $SCRIPTLOG for more details" | tee -a $SCRIPTLOG
else
	debug_info "Backup failed, please check $BACKUPLOG and $SCRIPTLOG for more details" 
fi
