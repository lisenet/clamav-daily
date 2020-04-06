#!/bin/bash
# written by Tomas Nevar (tomas@lisenet.com)
# 17/01/2014 (dd/mm/yy)
# copyleft free software
#
LOGFILE="/var/log/clamav/clamav-$(date +'%Y-%m-%d').log";
HOST="$(hostname --long)";
EMAIL_MSG="Please see the log file attached.";
EMAIL_FROM="clamav-daily@${HOST}";
EMAIL_TO="admin@example.com";
DIRTOSCAN="/home";

# Check for mail installation
type mail >/dev/null 2>&1 || { echo >&2 "I require mail but it's not installed. Aborting."; exit 1; };

# Update ClamAV database
echo "Looking for ClamAV database updates...";
freshclam --quiet;

TODAY=$(date +%u);

if [ "$TODAY" == "6" ];then
	echo "Starting a full weekend scan.";
	# be nice to others while scanning the entire root
	nice -n5 clamscan -ri / --exclude-dir=/sys/ --exclude-dir=/proc/ &>"${LOGFILE}";
else
	DIRSIZE=$(du -sh "${DIRTOSCAN}" 2>/dev/null|cut -f1);
	echo -e "Starting a daily scan of ${DIRTOSCAN} directory.\nAmount of data to be scanned is ${DIRSIZE}.";
	clamscan -ri "${DIRTOSCAN}" &>"${LOGFILE}";
fi

# get the value of "Infected lines"
MALWARE=$(tail "${LOGFILE}"|grep Infected|cut -d" " -f3);

# if the value is not equal to zero, send an email with the log file attached
if [ "${MALWARE}" -ne "0" ]; then
	echo "${EMAIL_MSG}"|mail -a "${LOGFILE}" -s "ClamAV: Malware Found" -r "${EMAIL_FROM}" "${EMAIL_TO}";
fi

echo "The script has finished.";
exit 0;
