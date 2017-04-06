#!/bin/sh
#
#Author: Avtar Singh, avtarsingh127@gmail.com
#Version: 0.1
#Prequesties: sudo apt-get install percona-xtrabackup
#####  SETTINGS  #####

DB=world               #can give multiple DB names comma separated
# What day to make the full weekly backup? Monday=1, Tuesday=2, .., Sunday=7
WEEKLYBACKUPDAY=7
WEEKLYBACKUPHOUR=01

# daily backup will be incremental backup from last full backup
# on first day, backup will be small because it will be contain one day data, but will increase every day
# Incremental backup frequency depends upon the cron job timing
# Incremental backup will be very fast, bacuase it will only take backup from last incremental backup
# For example if cronjob is setup after 1 hour for this script, Incremental backup will always contain last 1 hour changes only

# Backup directory
DIR=/opt/MySQLBackups
# Configuration file with username and password
DEFAULTS=/opt/MySQLBackups/server.cnf
# Log File
LOG=/opt/MySQLBackups/log/test.log
DEBUG=0   # Print Debug information, 0 to unset
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
		echo "DEBUG - $1"
	fi
	
}

# DEBUG
debug_info "DAYOFWEEK=$DAYOFWEEK"
debug_info "HOUROFDAY"
debug_info "DATELONG=$DATELONG"
debug_info "DATESHORT=$DATESHORT"
debug_info "WEEKLYBACKUPDAY=$WEEKLYBACKUPDAY"
debug_info "WEEKLYBACKUPHOUR=$WEEKLYBACKUPHOUR"
debug_info "DAILYBACKUPHOUR=$DAILYBACKUPHOUR"




checkdbconnection()
	{
		# Check if we can connect to the database
		echo "\q" | mysql --defaults-extra-file=$DEFAULTS 2> /dev/null
		if [ $? -ne 0 ]; then
		    echo "Error connecting to the database using $DEFAULTS, exiting..."
		    exit 1
		else
			echo "DB Connection Successful"
		fi
	}


make_dir()
	{

		# Check and Create the directories
		if [ ! -e "$DIR/full" ]; then
			mkdir -p "$DIR/full"
		fi

		if [ ! -e "$DIR/daily" ]		
			then
			mkdir -p "$DIR/daily"
		fi

		if [ ! -e "$DIR/log" ]		
			then
			mkdir -p "$DIR/log"
		fi
		
	}



# Will create full backup if called without checking anything for that date and time
full_backup()
{

	# Create a new backup for the day, week or month
	echo "We need to create a new backup for today: $DATELONG"
	#debug_info "create $DIR/$TYPE/$DATELONG"
	innobackupex --defaults-extra-file=$DEFAULTS  --databases=$DB --galera-info --compress $DIR/$TYPE 2>> $LOG
	# Print the status
	tail -n 3 $LOG
}

# Will create incremental backup in target directory ($1), based on ($2) without checking anything
incr_backup()
{	
	debug_info "4. LASTBACKUPPATH=$2"
	debug_info "5. TARGETDIR=$1"
	innobackupex --defaults-extra-file=$DEFAULTS  --databases=$DB --galera-info --compress --incremental $1 --incremental-basedir=$2 2>> $LOG
            # Print the status
            tail -n 3 $LOG
}


#This function will setup the initial type of backup based on settings of dates and hour
backup_type()
{
	# If weekly, set TYPE=weekly
	if [ $WEEKLYBACKUPDAY -eq $DAYOFWEEK -a $WEEKLYBACKUPHOUR = $HOUROFDAY ]; then
	    echo "Do Full backup: $DATELONG"
	    TYPE=full
	else
	    echo "Do Incremental backup: $DATELONG"
		TYPE=daily
	fi

}



find_base_and_target()
{
	# Check if we have an old backup for this day
	LASTBACKUPPATH=`ls -d $DIR/$TYPE/* | grep $DATESHORT | sort | tail -n 1` 2>/dev/null
	debug_info "1. LASTBACKUPPATH=$LASTBACKUPPATH"
	if [ "x$LASTBACKUPPATH" != 'x' ]; then
		#We have found the latest backup for today, we need to get any incremental backup inside this
		mkdir -p $LASTBACKUPPATH/incr

		LASTINCPATH=`ls -d $DIR/$type/incr/*/ | grep $DATESHORT | sort | tail -n 1` 2>/dev/null
		TARGETDIR=$LASTBACKUPPATH/incr  # incremental backup will be inside today's backup folder
		debug_info "1. TARGETDIR=$TARGETDIR"
		if [ "x$LASTINCPATH" != 'x' ]; then
			LASTBACKUPPATH=$LASTINCPATH
			
		#else
			# No incrmental backup inside, so parent backup will be used as base database for incr backup
		fi
	else
		TARGETDIR=$DIR/$TYPE/   #no backup for today, if last full not found, this variable will not be used, so safe to set now
		TYPE=full
		#No backup found for today, need to give last full backup as base 
		debug_info "1. DATESHORT=$DATESHORT"
		LASTBACKUPPATH=`ls -d $DIR/$TYPE/* | sort | tail -n 1` 2>/dev/null
		debug_info "2. LASTBACKUPPATH=$LASTBACKUPPATH"
		debug_info "2. TARGETDIR=$TARGETDIR"
		if [ "x$LASTBACKUPPATH" != 'x' ]; then
			TYPE=daily
			#Found last full backup and it will be used as base
			
		#else
			#No full backup found, LASTBACKUPPATH is set to null
			#Full backup is needed 
		fi
		
	fi
}

decider()
{
	
	if [ "x$TYPE" = 'xfull' ]; then
		echo "We are going to do a $TYPE backup"
		debug_info "Going inside full_backup"
		full_backup

	elif [ "x$TYPE" = 'xdaily' ]; then
		echo "We are going to do a $TYPE backup"
		find_base_and_target
		debug_info "LASTBACKUPPATH=$LASTBACKUPPATH"
		if [ "x$LASTBACKUPPATH" = 'x' ]; then
			debug_info "Full Backup needed"
			full_backup
		else
			debug_info "Doing incremental backup"
			debug_info "3. LASTBACKUPPATH=$LASTBACKUPPATH"
			debug_info "3. TARGETDIR=$TARGETDIR"
			incr_backup $TARGETDIR $LASTBACKUPPATH
		fi	
		
	
	else 
		echo "There is no backup scheduled for this time: $DATELONG"
		exit 0
	fi
}


cleanup_older()
{
	 # Clean up older backups
	ls -d $DIR/full/*/ | sort -r | awk "NR>$backup_copies {print $1}" | xargs rm -r 2>/dev/null
	#ls -d $DIR/full/*/ |sort -r| awk "NR>$backup_copies {print $1}">`/tmp/del.backup
	OLDESTFULL=`ls -d $DIR/full/*/ | sort | head -n 1`  #get the oldest full backup after delete
	if [ 'x' != "x$OLDESTFULL" ]; then #if there is any full backup left
		#get the short date from oldest full backup
		OLDESTFULLDATE=`echo $OLDESTFULL | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}'`
		OLDESTFULLDATE=`date -d $OLDESTFULLDATE +%s`   #Convert into Unix Timestamp for comparison
	#Loop through daily folder and get short date from each backup
	#Delete all those which has lesser date then $OLDESTFULLDATE
	for dir in $DIR/daily/*/
	do
		DAILYBACKUPDATE=`echo $dir | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}'`
		if [ 'x' != "x$DAILYBACKUPDATE" ]; then
			debug_info "1. DAILYBACKUPDATE: $DAILYBACKUPDATE"
			DAILYBACKUPDATE=`date -d $DAILYBACKUPDATE +%s`  #Convert into Unix Timestamp for comparison
			debug_info "2. DAILYBACKUPDATE: $DAILYBACKUPDATE"
			if [ $OLDESTFULLDATE -gt $DAILYBACKUPDATE ]; then 
				#backup is older than oldest full backup date
				rm -r $dir
			fi
		fi
	done
	fi
}

##### SCRIPT START POINT ####

checkdbconnection
make_dir
backup_type
decider
cleanup_older
echo "We are done"

