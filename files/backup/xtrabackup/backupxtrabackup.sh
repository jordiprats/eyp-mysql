#!/bin/bash

# puppet managed file

function initbck
{

	LOGDIR=${LOGDIR-$DESTINATION}

	if [ -z "${LOGDIR}" ];
	then
		echo "no destination defined"
		BCKFAILED=1
	else
		mkdir -p $LOGDIR
		BACKUPTS=$(date +%Y%m%d%H%M)

		CURRENTBACKUPLOG="$LOGDIR/$BACKUPTS.log"

		BCKFAILED=0

		if [ -z "$LOGDIR" ];
		then
			exec 2>&1
		else
			exec >> $CURRENTBACKUPLOG 2>&1
		fi
	fi
}

function mailer
{
	MAILCMD=$(which mail 2>/dev/null)
	if [ -z "$MAILCMD" ];
	then
		echo "mail not found, skipping"
	else
		if [ -z "$MAILTO" ];
		then
			echo "mail skipped, no MAILTO defined"
			exit $BCKFAILED
		else
			if [ -z "$LOGDIR" ];
			then
				if [ "$BCKFAILED" -eq 0 ];
				then
					echo "OK" | $MAILCMD -s "$IDHOST-${BACKUP_NAME_ID}-OK" $MAILTO
				else
					echo "ERROR - no log file configured" | $MAILCMD -s "$IDHOST-MySQL-ERROR" $MAILTO
				fi
			else
				if [ "$BCKFAILED" -eq 0 ];
				then
					$MAILCMD -s "$IDHOST-${BACKUP_NAME_ID}-OK" $MAILTO < $CURRENTBACKUPLOG
				else
					$MAILCMD -s "$IDHOST-${BACKUP_NAME_ID}-ERROR" $MAILTO < $CURRENTBACKUPLOG
				fi
			fi
		fi
	fi
}

function dobackup
{
	DUMPDEST="$DESTINATION"

	mkdir -p $DUMPDEST

	#aqui logica fulls/diferencials:

	if [ ! -z "$FULL_ON_MONTHDAY" ] && [ ! -z "$FULL_ON_WEEKDAY" ];
	then
		echo "FULL_ON_MONTHDAY and FULL_ON_WEEKDAY cannot be both defined"
		BCKFAILED=1
	elif [ ! -z "$FULL_ON_MONTHDAY" ];
	then
		# backup full on monthday definit
		TODAY_MONTHDAY="$(date +%e | awk '{ print $NF }')"
		TODAY_IS_FULL=0

		for i in $FULL_ON_MONTHDAY;
		do
			if [[ "$i" == "$TODAY_MONTHDAY" ]];
			then
				TODAY_IS_FULL=1
			fi
		done

	elif [ ! -z "$FULL_ON_WEEKDAY" ];
	then
		# backup full on weekday definit
		TODAY_WEEKDAY="$(date +%u)"
		TODAY_IS_FULL=0

		for i in $FULL_ON_WEEKDAY;
		do
			if [[ "$i" == "$TODAY_WEEKDAY" ]];
			then
				TODAY_IS_FULL=1
			fi
		done
	else
		# comportament no definit, fem fulls sempre
		TODAY_IS_FULL=1
	fi

	if [ "$TODAY_IS_FULL" -eq 1 ];
	then
		# full
		innobackupex ${MYSQL_INSTANCE_OPTS} ${DUMPDEST}
	else
		# incremental

		# buscar últim backup OK

		# innobackupex --incremental /var/backups/xtrabackup/ --incremental-basedir=/var/backups/xtrabackup/2014-08-25_10-04-45/

		# de moment full :D
		innobackupex ${MYSQL_INSTANCE_OPTS} ${DUMPDEST}
	fi

	if [ "$?" -ne 0 ];
	then
		echo "innobackupex error, check logs - error code: $?"
		BCKFAILED=1
	fi

	grep "completed OK!" ${CURRENTBACKUPLOG} > /dev/null 2>&1

	if [ "$?" -ne 0 ];
	then
		echo "innobackupex error - completed OK not found - unexpected log output, please check logs"
		BCKFAILED=1
	fi
}

function cleanup
{
	if [ -z "$RETENTION" ];
	then
		echo "cleanup skipped, no RETENTION defined"
	else
		find $LOGDIR -maxdepth 1 -mtime +$RETENTION -exec rm -fr {} \;
	fi
}

PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

BASEDIRBCK=$(dirname $0)
BASENAMEBCK=$(basename $0)
IDHOST=${IDHOST-$(hostname -s)}
BACKUP_NAME_ID=${BACKUP_NAME_ID-MySQL}

if [ ! -z "${INSTANCE_NAME}" ];
then
	MYSQL_INSTANCE_OPTS="--defaults-file=/etc/mysql/${INSTANCE_NAME}/my.cnf"
fi

if [ ! -z "$1" ] && [ -f "$1" ];
then
	. $1 2>/dev/null
else
	if [[ -s "$BASEDIRBCK/${BASENAMEBCK%%.*}.config" ]];
	then
		. $BASEDIRBCK/${BASENAMEBCK%%.*}.config 2>/dev/null
	else
		echo "config file missing"
		BCKFAILED=1
	fi
fi

INSTANCE_NAME=${INSTANCE_NAME-$1}

XTRABACKUPBIN=${XTRABACKUPBIN-$(which innobackupex 2>/dev/null)}
if [ -z "$XTRABACKUPBIN" ];
then
	echo "xtrabackup (innobackupex) not found"
	BCKFAILED=1
fi

#
#
#

initbck

if [ "$BCKFAILED" -ne 1 ];
then
	date
	dobackup
	date
fi

cleanup
mailer