clamav-daily
============

ClamAV is an open source (GPL) antivirus engine designed for detecting Trojans, viruses, malware and other malicious threats.

Rkhunter (Rootkit Hunter) is a Unix-based tool that scans for rootkits, backdoors and possible local exploits.

The script scans pre-defined system locations depending on the day of the week and sends an email notification with a ClamAV or rkhunter log attached if any malware has been found.

# Installation on Debian/Ubuntu

The following packages are used by the script:
 
* ClamAV
* bsd-mailx
* Rkhunter
 
To install:

<pre>
$ sudo apt-get install clamav clamav-freshclam bsd-mailx rkhunter git
$ git clone https://github.com/lisenet/clamav-daily.git
$ chmod u+x ./clamav-daily/*.sh
$ sudo ./clamav-daily/clamav-rkhunter-scan.sh
</pre>

# Installation on CentOS/Rocky

<pre>
$ sudo yum install epel-release
$ sudo yum install clamav clamav-update rkhunter mailx git
$ git clone https://github.com/lisenet/clamav-daily.git
$ chmod u+x ./clamav-daily/*.sh
$ sudo ./clamav-daily/clamav-rkhunter-scan.sh
</pre>

# Configuration

For systems that are up 24/7, you may want to put the script in the directory <code>/etc/cron.daily/</code> for daily execution.
