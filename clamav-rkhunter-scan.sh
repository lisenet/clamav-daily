#!/bin/bash
# AUTHOR:   Tomas Nevar (tomas@lisenet.com)
# NAME:     clamav-rkhunter-scan.sh
# VERSION:  1.1
# DATE:     17/01/2014 (dd/mm/yy)
# LICENCE:  Copyleft free software
#
# Variables
LOG_DIR="/var/log";
CLAMAV_LOG_DIR=""$LOG_DIR"/clamav";
FRESHCLAM_LOG=""$CLAMAV_LOG_DIR"/freshclam.log";
CLAMAV_LOG_FILE=""$CLAMAV_LOG_DIR"/clamav-$(date +'%Y-%m-%d').log";
RKHUNTER_LOG_FILE=""$LOG_DIR"/rkhunter.log";
RKHUNTER_CONFIG="rkhunter.local.conf";
HOST="$(hostname --long)";
EMAIL_MSG="Please see the log file attached.";
EMAIL_MSG_RKHUNTER=""$LOG_DIR"/rkhunter.msg";
EMAIL_FROM_CLAMAV="clamav-daily@"$HOST"";
EMAIL_FROM_RKHUNTER="rkhunter-daily@"$HOST"";
EMAIL_TO="user@example.com";

# This is a ClamAV directory array to scan.
DIR_ARRAY=(/var/www /home)

# This folder will be excluded from ClamAV scan.
DIRTOEXCLUDE="/backups";

#
# Sanity checks
#

# Check for software installation.
if ! type mail >/dev/null 2>&1; then
    echo "I require mail but it's not installed. Aborting.";
    echo "On Debian try: apt-get install heirloom-mailx";
    exit 1;
elif ! type clamscan >/dev/null 2>&1; then
    echo "I require clamscan but it's not installed. Aborting.";
    echo "On Debian try: apt-get install clamav clamav-freshclam";
    exit 1;
elif ! type rkhunter >/dev/null 2>&1; then
    echo "I require rkhunter but it's not installed. Aborting.";
    echo "On Debian try: apt-get install rkhunter";
    exit 1;
fi

# Check for ClamAV log folder.
if [ ! -d "$CLAMAV_LOG_DIR" ]; then
    mkdir -p -m 0750 "$CLAMAV_LOG_DIR";
    chown clamav:clamav "$CLAMAV_LOG_DIR";
fi

#############################################
#                 CLAMAV                    #
#############################################

# Update ClamAV database.
echo "Antivirus version installed:";
freshclam -V;
echo "Looking for ClamAV database updates.";
if [ -f "$FRESHCLAM_LOG" ]; then
    # Log file causes pain sometimes.
    rm "$FRESHCLAM_LOG" -rf;
fi

freshclam --quiet;
rm "$FRESHCLAM_LOG" -rf;

if [ "$(date +%u)" == "6" ];then
    echo "Starting a full weekend ClamAV scan.";
    echo "Excluding from scan: ""$DIRTOEXCLUDE";
    # Be nice to others while scanning the entire root.
    nice -n5 clamscan -ri / --exclude-dir=/sys/ --exclude-dir="$DIRTOEXCLUDE" >"$CLAMAV_LOG_FILE" 2>&1;
else
    for dir in ${DIR_ARRAY[@]};do
        DIRSIZE=$(du -sh "$dir"  2>/dev/null|cut -f1);
        echo -e "Starting a daily ClamAV scan of "$dir" directory.\nThe amount of data to be scanned is "$DIRSIZE".";
        clamscan -ri "$dir" --exclude-dir=/sys/ --exclude-dir="$DIRTOEXCLUDE" >"$CLAMAV_LOG_FILE" 2>&1;

        #############################################
        #        CLAMAV EMAIL NOTIFICATIONS         #
        #############################################

        # Get the value of "Infected lines" from clamscan.
        MALWARE=$(tail "$CLAMAV_LOG_FILE"|grep Infected|cut -d" " -f3);

        # If the value is not equal to zero, send an email with the ClamAV log file attached.
        if [ "$MALWARE" -ne "0" ]; then
            echo "$EMAIL_MSG"|mail -a "$CLAMAV_LOG_FILE" -s "[ClamAV] Malware Found" \
              -r "$EMAIL_FROM_CLAMAV" "$EMAIL_TO";
        ##else
            ##echo "No malware found."|mail -s "[ClamAV] OK" -r "$EMAIL_FROM_CLAMAV" "$EMAIL_TO";
        fi

        # Check if any ClamAV errors were raised.
        if grep -i error "$CLAMAV_LOG_FILE" >/dev/null; then
            echo "$EMAIL_MSG"|mail -a "$CLAMAV_LOG_FILE" -s "[ClamAV] Errors Found" \
              -r "$EMAIL_FROM_CLAMAV" "$EMAIL_TO";
        fi
    done
fi

#############################################
#               RKHUNTER                    #
#############################################

# Create a local rkhunter configuration file to use.
# This should be configured according to your needs.
cat <<EOL >"$RKHUNTER_CONFIG"
ROTATE_MIRRORS=1
UPDATE_MIRRORS=1
MIRRORS_MODE=0
TMPDIR=/var/lib/rkhunter/tmp
DBDIR=/var/lib/rkhunter/db
SCRIPTDIR=/usr/share/rkhunter/scripts
LANGUAGE=en
UPDATE_LANG="en"
LOGFILE=$RKHUNTER_LOG_FILE
APPEND_LOG=0
COPY_LOG_ON_ERROR=0
COLOR_SET2=0
AUTO_X_DETECT=1
WHITELISTED_IS_WHITE=0
ALLOW_SSH_ROOT_USER=no
ALLOW_SSH_PROT_V1=0
ENABLE_TESTS="all"
DISABLE_TESTS="suspscan hidden_procs deleted_files packet_cap_apps apps loaded_modules"
PKGMGR=NONE
SCRIPTWHITELIST=/bin/egrep
SCRIPTWHITELIST=/bin/fgrep
SCRIPTWHITELIST=/bin/which
SCRIPTWHITELIST=/usr/bin/groups
SCRIPTWHITELIST=/usr/bin/ldd
SCRIPTWHITELIST=/usr/bin/lwp-request
SCRIPTWHITELIST=/usr/sbin/adduser
SCRIPTWHITELIST=/usr/sbin/prelink
IMMUTABLE_SET=0
ALLOWHIDDENDIR="/dev/.udev"
ALLOWDEVFILE="/dev/.udev/rules.d/root.rules"
PHALANX2_DIRTEST=0
ALLOW_SYSLOG_REMOTE_LOGGING=0
SUSPSCAN_TEMP=/dev/shm
SUSPSCAN_MAXSIZE=10240000
SUSPSCAN_THRESH=200
USE_LOCKING=0
LOCK_TIMEOUT=300
SHOW_LOCK_MSGS=1
DISABLE_UNHIDE=1
INSTALLDIR="/usr"
MAIL-ON-WARNING=$EMAIL_TO
MAIL_CMD=cat $EMAIL_MSG_RKHUNTER|mail -s "[rkhunter] Warnings Found" -a $RKHUNTER_LOG_FILE -r $EMAIL_FROM_RKHUNTER
EOL

# Update rkhunter database.
echo "Looking for rkhunter updates.";
rkhunter --update;

# Scan for rootkits.
echo "Starting a daily rkhunter scan.";
nice rkhunter --configfile "$RKHUNTER_CONFIG" --cronjob --report-warnings-only \
  --logfile "$RKHUNTER_LOG_FILE" >"$EMAIL_MSG_RKHUNTER";
rm "$RKHUNTER_CONFIG" -f;

echo "The script has finished.";
exit 0;
