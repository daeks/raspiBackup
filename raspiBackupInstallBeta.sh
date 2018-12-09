#!/usr/bin/env bash
#######################################################################################################################
#
# Script to download, install, configure and uninstall raspiBackup.sh
#
# Visit http://www.linux-tips-and-tricks.de/raspiBackup for latest code and other details
#
#######################################################################################################################
#
#    Copyright (C) 2015-2018 framp at linux-tips-and-tricks dot de
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################################################################

#set -o errexit nounset pipefail

MYSELF=${0##*/}
MYNAME=${MYSELF%.*}
VERSION="0.4-beta"

MYHOMEDOMAIN="www.linux-tips-and-tricks.de"
MYHOMEURL="https://$MYHOMEDOMAIN"

MYDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GIT_DATE="$Date: 2018-11-28 20:44:17 +0100$"
GIT_DATE_ONLY=${GIT_DATE/: /}
GIT_DATE_ONLY=$(cut -f 2 -d ' ' <<<$GIT_DATE)
GIT_TIME_ONLY=$(cut -f 3 -d ' ' <<<$GIT_DATE)
GIT_COMMIT="$Sha1: e0366e8$"
GIT_COMMIT_ONLY=$(cut -f 2 -d ' ' <<<$GIT_COMMIT | sed 's/\$//')

GIT_CODEVERSION="$MYSELF $VERSION, $GIT_DATE_ONLY/$GIT_TIME_ONLY - $GIT_COMMIT_ONLY"

FILE_TO_INSTALL="raspiBackup.sh"

RASPIBACKUP_NAME=${FILE_TO_INSTALL%.*}
RASPIBACKUP_INSTALL_DEBUG=1

NL=$'\n'
FILE_TO_INSTALL_BETA="raspiBackup_beta.sh"
declare -A CONFIG_DOWNLOAD_FILE=(['DE']="raspiBackup_de.conf" ['EN']="raspiBackup_en.conf")
CONFIG_FILE="raspiBackup.conf"
SAMPLEEXTENSION_TAR_FILE="raspiBackupSampleExtensions.tgz"

read -r -d '' CRON_CONTENTS <<-'EOF'
#
# Crontab entry for raspiBackup.sh
#
# (C) 2017-2018 framp at linux-tips-and-tricks dot de
#
# Create a backup once a week on Sunday morning at 5 am (default)
#
#0 5 * * 0	root	PATH=\"$PATH:/usr/local/bin\"	raspiBackup.sh
EOF

PROPERTY_URL="downloads/raspibackup0613-properties/download"
BETA_CODE_URL="downloads/$FILE_TO_INSTALL_BETA/download"
INSTALLER_PROPERTY_URL="$MYHOMEURL/downloads/raspibackupinstall-properties/download"

STABLE_CODE_URL="$FILE_TO_INSTALL"

DOWNLOAD_TIMEOUT=60 # seconds

BIN_DIR="/usr/local/bin"
ETC_DIR="/usr/local/etc"
CRON_DIR="/etc/cron.d"
LOG_FILE="$MYNAME.log"

CONFIG_FILE_ABS_PATH="$ETC_DIR"
CONFIG_ABS_FILE="$CONFIG_FILE_ABS_PATH/$CONFIG_FILE"
FILE_TO_INSTALL_ABS_PATH="$BIN_DIR"
FILE_TO_INSTALL_ABS_FILE="$FILE_TO_INSTALL_ABS_PATH/$FILE_TO_INSTALL"
CRON_ABS_FILE="$CRON_DIR/$RASPIBACKUP_NAME"

if [ $(id -u) -ne 0 ]; then
	printf "Script must be run as root. Try 'sudo raspi-config'\n"
	exit 1
fi

rm $LOG_FILE

[ -z ${LANG+x} ] && LANG="en_US.UTF-8"
LANG_EXT=${LANG,,*}
LANG_SYSTEM=${LANG_EXT:0:2}
if [[ $LANG_SYSTEM != "de" && $LANG_SYSTEM != "en" ]]; then
	LANG_SYSTEM="en"
fi

# default configs
CONFIG_LANGUAGE=${LANG_SYSTEM^^*}
CONFIG_MSG_LEVEL="0"
CONFIG_BACKUPTYPE="rsync"
CONFIG_COMPRESS="0"
CONFIG_KEEPBACKUPS="3"
CONFIG_PARTITIONBASED_BACKUP="n"
CONFIG_ZIP_BACKUP="0"
CONFIG_CRON_HOUR="5"
CONFIG_CRON_MINUTE="0"
CONFIG_CRON_DAY="0"

#exec 1> >(stdbuf -i0 -o0 -e0 tee -a "$LOG_FILE" >&1)
#exec 2> >(stdbuf -i0 -o0 -e0 tee -a "$LOG_FILE" >&2)

logOff() {
	exec 1>&-
	exec 2>&-
}

[[ -z ${LANG+x} ]] && LANG="EN"
LANG_EXT=${LANG^^*}
MESSAGE_LANGUAGE=${LANG_EXT:0:2}
if [[ $MESSAGE_LANGUAGE != "DE" && $MESSAGE_LANGUAGE != "EN" ]]; then
	MESSAGE_LANGUAGE="EN"
fi

case $MESSAGE_LANGUAGE in
DE)
	confFile=${CONFIG_DOWNLOAD_FILE["DE"]}
	;;
*)
	confFile=${CONFIG_DOWNLOAD_FILE["EN"]}
	;;
esac

ROWS_MSGBOX=10
ROWS_ABOUT=12
ROWS_MENU=20
WINDOW_COLS=60

MSG_EN=1 # english	(default)
MSG_DE=1 # german

MSG_PRF="RBI"

declare -A MSG_EN
declare -A MSG_DE

MSG_UNDEFINED=0
MSG_EN[$MSG_UNDEFINED]="${MSG_PRF}0000E: Undefined messageid."
MSG_DE[$MSG_UNDEFINED]="${MSG_PRF}0000E: Unbekannte Meldungsid."
MSG_VERSION=1
MSG_EN[$MSG_VERSION]="${MSG_PRF}0001I: %1"
MSG_DE[$MSG_VERSION]="${MSG_PRF}0001I: %1"
MSG_ASK_LANGUAGE=2
MSG_EN[$MSG_ASK_LANGUAGE]="${MSG_PRF}0002I: Message language (%1)"
MSG_DE[$MSG_ASK_LANGUAGE]="${MSG_PRF}0002I: Sprache der Meldungen (%1)"
MSG_ASK_MODE=3
MSG_EN[$MSG_ASK_MODE]="${MSG_PRF}0003I: Normal or partition oriented mode (%1)"
MSG_DE[$MSG_ASK_MODE]="${MSG_PRF}0003I: Normaler oder partitionsorientierter Modus (%1)"
MSG_ASK_TYPE1=4
MSG_EN[$MSG_ASK_TYPE1]="${MSG_PRF}0004I: Backuptype (%1)"
MSG_DE[$MSG_ASK_TYPE1]="${MSG_PRF}0004I: Backuptyp (%1)"
MSG_ASK_TYPE2=5
MSG_EN[$MSG_ASK_TYPE2]="${MSG_PRF}0004I: Backuptype (%1)"
MSG_DE[$MSG_ASK_TYPE2]="${MSG_PRF}0004I: Backuptyp (%1)"
MSG_ASK_KEEP=6
MSG_EN[$MSG_ASK_KEEP]="${MSG_PRF}0006I: Number of backups (1-52)"
MSG_DE[$MSG_ASK_KEEP]="${MSG_PRF}0006I: Anzahl der Backups (1-52)"
MSG_ANSWER_CHARS_YES_NO=7
MSG_EN[$MSG_ANSWER_CHARS_YES_NO]="y|n"
MSG_DE[$MSG_ANSWER_CHARS_YES_NO]="j|n"
MSG_ASK_DETAILS=8
MSG_EN[$MSG_ASK_DETAILS]="${MSG_PRF}0008I: Verbose messages (%1)"
MSG_DE[$MSG_ASK_DETAILS]="${MSG_PRF}0008I: Ausführliche Meldungen (%1)"
MSG_CONF_OK=9
MSG_EN[$MSG_CONF_OK]="${MSG_PRF}0009I: Configuration OK (%1)"
MSG_DE[$MSG_CONF_OK]="${MSG_PRF}0009I: Konfiguration OK (%1)"
MSG_INVALID_MESSAGE=10
MSG_EN[$MSG_INVALID_MESSAGE]="${MSG_PRF}0010E: Invalid language %1."
MSG_DE[$MSG_INVALID_MESSAGE]="${MSG_PRF}0010E: Ungültige Sprache %1."
MSG_INVALID_OPTION=11
MSG_EN[$MSG_INVALID_OPTION]="${MSG_PRF}0011E: Invalid option %1."
MSG_DE[$MSG_INVALID_OPTION]="${MSG_PRF}0011E: Ungültige Option %1."
MSG_PARAMETER_EXPECTED=12
MSG_EN[$MSG_PARAMETER_EXPECTED]="${MSG_PRF}0012E: Parameter expected for option %1."
MSG_DE[$MSG_PARAMETER_EXPECTED]="${MSG_PRF}0012E: Parameter erwartet bei Option %1."
MSG_SUDO_REQUIRED=13
MSG_EN[$MSG_SUDO_REQUIRED]="${MSG_PRF}0013E: Installation script needs root access. Try 'sudo %1'."
MSG_DE[$MSG_SUDO_REQUIRED]="${MSG_PRF}0013E: Das Installationsscript benötigt root Rechte. Versuche es mit 'sudo %1'."
MSG_DOWNLOADING=14
MSG_EN[$MSG_DOWNLOADING]="${MSG_PRF}0014I: Downloading %1..."
MSG_DE[$MSG_DOWNLOADING]="${MSG_PRF}0014I: %1 wird aus dem Netz geladen..."
MSG_DOWNLOAD_FAILED=15
MSG_EN[$MSG_DOWNLOAD_FAILED]="${MSG_PRF}0015E: Download of %1 failed. HTTP code: %2."
MSG_DE[$MSG_DOWNLOAD_FAILED]="${MSG_PRF}0015E: %1 kann nicht aus dem Netz geladen werden. HTTP code: %2."
MSG_INSTALLATION_FAILED=16
MSG_EN[$MSG_INSTALLATION_FAILED]="${MSG_PRF}0016E: Installation of %1 failed. Check %2."
MSG_DE[$MSG_INSTALLATION_FAILED]="${MSG_PRF}0016E: Installation von %1 fehlerhaft beendet. Prüfe %2."
MSG_SAVING_FILE=17
MSG_EN[$MSG_SAVING_FILE]="${MSG_PRF}0017I: Existing file %1 saved as %2."
MSG_DE[$MSG_SAVING_FILE]="${MSG_PRF}0017I: Existierende Datei %1 wurde als %2 gesichert."
MSG_CHMOD_FAILED=18
MSG_EN[$MSG_CHMOD_FAILED]="${MSG_PRF}0018E: chmod of %1 failed."
MSG_DE[$MSG_CHMOD_FAILED]="${MSG_PRF}0018E: chmod von %1 nicht möglich."
MSG_MOVE_FAILED=19
MSG_EN[$MSG_MOVE_FAILED]="${MSG_PRF}0019E: mv of %1 failed."
MSG_DE[$MSG_MOVE_FAILED]="${MSG_PRF}0019E: mv von %1 nicht möglich."
MSG_NO_BETA_AVAILABLE=20
MSG_EN[$MSG_NO_BETA_AVAILABLE]="${MSG_PRF}0020I: No beta available right now."
MSG_DE[$MSG_NO_BETA_AVAILABLE]="${MSG_PRF}0020I: Momentan kein Beta verfügbar."
MSG_READ_LOG=21
MSG_EN[$MSG_READ_LOG]="${MSG_PRF}0021I: See logfile %1 for details."
MSG_DE[$MSG_READ_LOG]="${MSG_PRF}0021I: Siehe Logdatei %1 für weitere Details."
MSG_CLEANUP=22
MSG_EN[$MSG_CLEANUP]="${MSG_PRF}0022I: Cleaning up..."
MSG_DE[$MSG_CLEANUP]="${MSG_PRF}0022I: Räume auf..."
MSG_INSTALLATION_FINISHED=23
MSG_EN[$MSG_INSTALLATION_FINISHED]="${MSG_PRF}0023I: Installation of %1 finished successfully."
MSG_DE[$MSG_INSTALLATION_FINISHED]="${MSG_PRF}0023I: Installation von %1 erfolgreich beendet."
MSG_UPDATING_CONFIG=24
MSG_EN[$MSG_UPDATING_CONFIG]="${MSG_PRF}0024I: Updating configuration in %1."
MSG_DE[$MSG_UPDATING_CONFIG]="${MSG_PRF}0024I: Konfigurationsdatei %1 wird angepasst."
MSG_ASK_COMPRESS=25
MSG_EN[$MSG_ASK_COMPRESS]="${MSG_PRF}0025I: Compress backup (%1)"
MSG_DE[$MSG_ASK_COMPRESS]="${MSG_PRF}0025I: Backup komprimieren (%1)"
MSG_NEWLINE=26
MSG_EN[$MSG_NEWLINE]="$NL"
MSG_DE[$MSG_NEWLINE]="$NL"
MSG_ASK_UNINSTALL=27
MSG_EN[$MSG_ASK_UNINSTALL]="${MSG_PRF}0027I: Are you sure to uninstall $RASPIBACKUP_NAME (%1)"
MSG_DE[$MSG_ASK_UNINSTALL]="${MSG_PRF}0027I: Soll $RASPIBACKUP_NAME wirklich deinstalliert werden (%1)"
MSG_DELETE_FILE=28
MSG_EN[$MSG_DELETE_FILE]="${MSG_PRF}0028I: Deleting %1..."
MSG_DE[$MSG_DELETE_FILE]="${MSG_PRF}0028I: Lösche %1..."
MSG_UNINSTALL_FINISHED=29
MSG_EN[$MSG_UNINSTALL_FINISHED]="${MSG_PRF}0029I: Uninstall of %1 finished successfully."
MSG_DE[$MSG_UNINSTALL_FINISHED]="${MSG_PRF}0029I: Deinstallation von %1 erfolgreich beendet."
MSG_UNINSTALL_FAILED=30
MSG_EN[$MSG_UNINSTALL_FAILED]="${MSG_PRF}0030E: Delete of %1 failed."
MSG_DE[$MSG_UNINSTALL_FAILED]="${MSG_PRF}0030E: Löschen von %1 fehlerhaft beendet."
MSG_DOWNLOADING_BETA=31
MSG_EN[$MSG_DOWNLOADING_BETA]="${MSG_PRF}0031I: Downloading %1 beta..."
MSG_DE[$MSG_DOWNLOADING_BETA]="${MSG_PRF}0031I: %1 beta wird aus dem Netz geladen..."
MSG_CHECKING_FOR_BETA=32
MSG_EN[$MSG_CHECKING_FOR_BETA]="${MSG_PRF}0032I: Checking if there is a beta version available."
MSG_DE[$MSG_CHECKING_FOR_BETA]="${MSG_PRF}0032I: Prüfung ob eine Betaversion verfügbar ist."
MSG_BETAVERSION_AVAILABLE=33
MSG_EN[$MSG_BETAVERSION_AVAILABLE]="${MSG_PRF}0033I: Beta version %1 is available."
MSG_DE[$MSG_BETAVERSION_AVAILABLE]="${MSG_PRF}0033I: Beta Version %1 ist verfügbar."
MSG_ASK_INSTALLBETA=34
MSG_EN[$MSG_ASK_INSTALLBETA]="${MSG_PRF}0034I: Install beta version (Y|n)"
MSG_DE[$MSG_ASK_INSTALLBETA]="${MSG_PRF}0034I: Soll die Betaversion installiert werden (J|n)"
MSG_INSTALLING_BETA=35
MSG_EN[$MSG_INSTALLING_BETA]="${MSG_PRF}0035I: Installing beta version %1"
MSG_DE[$MSG_INSTALLING_BETA]="${MSG_PRF}0035I: Die Betaversion %1 wird installiert"
MSG_BETA_THANKYOU=36
MSG_EN[$MSG_BETA_THANKYOU]="${MSG_PRF}0036I: Thank you very much for helping to test %1 %2."
MSG_DE[$MSG_BETA_THANKYOU]="${MSG_PRF}0036I: Vielen Dank für die Hilfe beim Testen von %1 %2."
MSG_CODE_INSTALLED=37
MSG_EN[$MSG_CODE_INSTALLED]="${MSG_PRF}0037I: Created %1."
MSG_DE[$MSG_CODE_INSTALLED]="${MSG_PRF}0037I: %1 wurde erstellt."
MSG_NO_INSTALLATION_FOUND=38
MSG_EN[$MSG_NO_INSTALLATION_FOUND]="${MSG_PRF}0038W: No installation to refresh detected."
MSG_DE[$MSG_NO_INSTALLATION_FOUND]="${MSG_PRF}0038W: Keine Installation für einen Update entdeckt."
MSG_CHOWN_FAILED=39
MSG_EN[$MSG_CHOWN_FAILED]="${MSG_PRF}0039E: chown of %1 failed."
MSG_DE[$MSG_CHOWN_FAILED]="${MSG_PRF}0039E: chown von %1 nicht möglich."
MSG_ANSWER_CHARS_YES=40
MSG_EN[$MSG_ANSWER_CHARS_YES]="y"
MSG_DE[$MSG_ANSWER_CHARS_YES]="j"
MSG_ANSWER_CHARS_NO=41
MSG_EN[$MSG_ANSWER_CHARS_NO]="n"
MSG_DE[$MSG_ANSWER_CHARS_NO]="n"
MSG_CONFIG_INFO=42
MSG_EN[$MSG_CONFIG_INFO]="${MSG_PRF}0041I: Default option is in UPPERCASE."
MSG_DE[$MSG_CONFIG_INFO]="${MSG_PRF}0041I: Bei keiner Eingabe wird der Wert in GROSSBUCHSTABEN benutzt."
MSG_SELECTED_CONFIG_PARMS1=43
MSG_EN[$MSG_SELECTED_CONFIG_PARMS1]="${MSG_PRF}0042I: Selected configuration: Message language: %1, Backupmode: %2, Backuptype: %3"
MSG_DE[$MSG_SELECTED_CONFIG_PARMS1]="${MSG_PRF}0042I: Gewählte Konfiguration: Sprache der Meldungen: %1, Backupmodus: %2, Backuptype: %3"
MSG_NORMAL_MODE=44
MSG_EN[$MSG_NORMAL_MODE]="normal"
MSG_DE[$MSG_NORMAL_MODE]="normal"
MSG_PARTITION_MODE=45
MSG_EN[$MSG_PARTITION_MODE]="partition oriented"
MSG_DE[$MSG_PARTITION_MODE]="partitionsorientiert"
MSG_SAMPLEEXTENSION_INSTALL_FAILED=46
MSG_EN[$MSG_SAMPLEEXTENSION_INSTALL_FAILED]="${MSG_PRF}0046E: Sample extension installation failed. %1"
MSG_DE[$MSG_SAMPLEEXTENSION_INSTALL_FAILED]="${MSG_PRF}0046E: Beispielserweiterungsinstallation fehlgeschlagen. %1"
MSG_SAMPLEEXTENSION_INSTALL_SUCCESS=47
MSG_EN[$MSG_SAMPLEEXTENSION_INSTALL_SUCCESS]="${MSG_PRF}0047I: Sample extensions successfully installed and enabled."
MSG_DE[$MSG_SAMPLEEXTENSION_INSTALL_SUCCESS]="${MSG_PRF}0047I: Beispielserweiterungen erfolgreich installiert und eingeschaltet."
MSG_SELECTED_CONFIG_PARMS2=48
MSG_EN[$MSG_SELECTED_CONFIG_PARMS2]="${MSG_PRF}0048I: Selected configuration: Compress backups: %1, Number of backups: %2, Verbose messages: %3"
MSG_DE[$MSG_SELECTED_CONFIG_PARMS2]="${MSG_PRF}0048I: Gewählte Konfiguration: Backup komprimieren: %1, Anzahl Backups: %2, Ausführliche Meldungen: %3"
MSG_INSTALLING_CRON_TEMPLATE=49
MSG_EN[$MSG_INSTALLING_CRON_TEMPLATE]="${MSG_PRF}0049I: Creating cron file %1."
MSG_DE[$MSG_INSTALLING_CRON_TEMPLATE]="${MSG_PRF}0049I: Crondatei %1 wird erstellt."
MSG_BIN_DIR_NOT_FOUND=50
MSG_EN[$MSG_BIN_DIR_NOT_FOUND]="${MSG_PRF}0050E: %1 does not exist. Use option -B to define the bin target directory."
MSG_DE[$MSG_BIN_DIR_NOT_FOUND]="${MSG_PRF}0050E: %1 existiert nicht. Benutze Option -B um das bin Zielverzeichnis anzugeben."
MSG_ETC_DIR_NOT_FOUND=51
MSG_EN[$MSG_ETC_DIR_NOT_FOUND]="${MSG_PRF}0051E: %1 does not exist. Use option -E to define the etc target directory."
MSG_DE[$MSG_ETC_DIR_NOT_FOUND]="${MSG_PRF}0051E: %1 existiert nicht. Benutze Option -E um das etc Zielverzeichnis anzugeben."
MSG_CRON_DIR_NOT_FOUND=52
MSG_EN[$MSG_CRON_DIR_NOT_FOUND]="${MSG_PRF}0052E: %1 does not exist. Use option -C to define the cron target directory."
MSG_DE[$MSG_CRON_DIR_NOT_FOUND]="${MSG_PRF}0052E: %1 existiert nicht. Benutze Option -C um das cron Zielverzeichnis anzugeben."
MSG_INSTALLING_VERSION=53
MSG_EN[$MSG_INSTALLING_VERSION]="${MSG_PRF}0053I: Installing $FILE_TO_INSTALL %1."
MSG_DE[$MSG_INSTALLING_VERSION]="${MSG_PRF}0053I: Installiere $FILE_TO_INSTALL %1."
MSG_LOGFILE_ERROR=54
MSG_EN[$MSG_LOGFILE_ERROR]="${MSG_PRF}0054E: Unable to create logfile %1."
MSG_DE[$MSG_LOGFILE_ERROR]="${MSG_PRF}0054E: Logdatei %1 kann nicht erstellt werden."
MSG_USING_LOGFILE=55
MSG_EN[$MSG_USING_LOGFILE]="${MSG_PRF}0055I: Using logfile %1."
MSG_DE[$MSG_USING_LOGFILE]="${MSG_PRF}0055I: Logdatei ist %1 ."
MSG_NO_INTERNET_CONNECTION_FOUND=56
MSG_EN[$MSG_NO_INTERNET_CONNECTION_FOUND]="${MSG_PRF}0056E: Unable to connect to internet. wget RC: %1"
MSG_DE[$MSG_NO_INTERNET_CONNECTION_FOUND]="${MSG_PRF}0056E: Es existiert keine Internetverbindung. wget RC: %1"
MSG_CHECK_INTERNET_CONNECTION=57
MSG_EN[$MSG_CHECK_INTERNET_CONNECTION]="${MSG_PRF}0057I: Checking internet connection."
MSG_DE[$MSG_CHECK_INTERNET_CONNECTION]="${MSG_PRF}0057I: Teste Internetverbindung."
MSG_SAMPLEEXTENSION_UNINSTALL_FAILED=58
MSG_EN[$MSG_SAMPLEEXTENSION_UNINSTALL_FAILED]="${MSG_PRF}0058E: Sample extension uninstallation failed. %1"
MSG_DE[$MSG_SAMPLEEXTENSION_UNINSTALL_FAILED]="${MSG_PRF}0058E: Beispielserweiterungsdeinstallation fehlgeschlagen. %1"
MSG_SAMPLEEXTENSION_UNINSTALL_SUCCESS=59
MSG_EN[$MSG_SAMPLEEXTENSION_UNINSTALL_SUCCESS]="${MSG_PRF}0059I: Sample extensions successfully uninstalled and disenabled."
MSG_DE[$MSG_SAMPLEEXTENSION_UNINSTALL_SUCCESS]="${MSG_PRF}0059I: Beispielserweiterungen erfolgreich deinstalliert und ausgeschaltet."
MSG_UNINSTALLING_CRON_TEMPLATE=60
MSG_EN[$MSG_UNINSTALLING_CRON_TEMPLATE]="${MSG_PRF}0060I: Deleting cron file %1."
MSG_DE[$MSG_UNINSTALLING_CRON_TEMPLATE]="${MSG_PRF}0060I: Crondatei %1 wird gelöscht."
MSG_UPDATING_CRON=61
MSG_EN[$MSG_UPDATING_CRON]="${MSG_PRF}0062I: Updating cron configuration in %1."
MSG_DE[$MSG_UPDATING_CRON]="${MSG_PRF}0062I: Cron Konfigurationsdatei %1 wird angepasst."

declare -A MSG_HEADER=(['I']="---" ['W']="!!!" ['E']="???")

INSTALLATION_SUCCESSFULL=0
INSTALLATION_WARNING=0
INSTALLATION_STARTED=0
CONFIG_INSTALLED=0
SCRIPT_INSTALLED=0
EXTENSIONS_INSTALLED=0
CRON_INSTALLED=0

INSTALL_EXTENSIONS=0
BETA_INSTALL=0
REFRESH_SCRIPT=0

# Create message and substitute parameters

getMessageText() { # languageflag messagenumber parm1 parm2 ...

	local msg
	local p
	local i
	local s

	if [[ $1 != "L" ]]; then
		LANG_SUFF=${1^^*}
	else
		LANG_EXT=${LANG^^*}
		LANG_SUFF=${LANG_EXT:0:2}
	fi

	msgVar="MSG_${LANG_SUFF}"

	if [[ -n ${!msgVar} ]]; then
		msgVar="$msgVar[$2]"
		msg=${!msgVar}
		if [[ -z $msg ]]; then # no translation found
			msgVar="$2"
			if [[ -z ${!msgVar} ]]; then
				echo "${MSG_EN[$MSG_UNDEFINED]}" # unknown message id
				logStack
				return
			else
				msg="${MSG_EN[$2]}" # fallback into english
			fi
		fi
	else
		msg="${MSG_EN[$2]}" # fallback into english
	fi

	for ((i = 3; $i <= $#; i++)); do # substitute all message parameters
		p=${!i}
		let s=$i-2
		s="%$s"
		msg="$(sed "s|$s|$p|" <<<"$msg" 2>/dev/null)" # have to use explicit command name
	done

	msg="$(sed "s/%[0-9]+//g" <<<"$msg" 2>/dev/null)" # delete trailing %n definitions

	local msgPref=${msg:0:3}
	if [[ $msgPref == "RBK" ]]; then # RBK0001E
		local severity=${msg:7:1}
		if [[ "$severity" =~ [EWI] ]]; then
			local msgHeader=${MSG_HEADER[$severity]}
			echo "$msgHeader $msg"
		else
			echo "$msg"
		fi
	else
		echo "$msg"
	fi
}

getLocalizedMessage() { # messageNumber parm1 parm2

	local msg
	msg="$(getMessageText $CONFIG_LANGUAGE "$@")"
	echo "$msg"
}

writeToConsole() {
	local msg="$(getMessageText $MESSAGE_LANGUAGE "$@")"
	echo "MSG: $msg" >>"$LOG_FILE"
	if (( MODE_UNATTENDED )); then
		echo "$msg"
	fi
}

log() {
	echo "DBG: $@" >>"$LOG_FILE"
}

finished() {
	:
}

center() { # <cols> <text>
	local columns="$1"
	shift 1
	while IFS= read -r line; do
		printf "%*s\n" $(((${#line} + columns) / 2)) "$line"
	done <<<"$@"
}

isCrontabEnabled() {
	if isConfigInstalled; then
		log "Config installed: yes"
		local l="$(tail -n 1 < $CRON_ABS_FILE)"
		log "$l"
		[[ ${l:0:1} == "#" ]] && return 1 || return 0
	fi
	return 1
}

isCrontabInstalled() {
	log "$(ls -a $CRON_ABS_FILE)"
	[[ -f $CRON_ABS_FILE ]]
	return $?
}

isConfigInstalled() {
	[[ -f $CONFIG_ABS_FILE ]]
	return $?
}

isExtensionInstalled() {
	ls $FILE_TO_INSTALL_ABS_PATH/${RASPIBACKUP_NAME}_*.sh 2>/dev/null &>>"$LOG_FILE"
	return $?
}

isRaspiBackupInstalled() {
	[[ -f $FILE_TO_INSTALL_ABS_FILE ]]
	return $?
}

code_download_execute() {

	log "code_download_execute"

	local newName

	if [[ -f "$FILE_TO_INSTALL_ABS_FILE" ]]; then
		oldVersion=$(grep -o -E "^VERSION=\".+\"" "$FILE_TO_INSTALL_ABS_FILE" | sed -e "s/VERSION=//" -e "s/\"//g")
		newName="$FILE_TO_INSTALL_ABS_FILE.$oldVersion.sh"
		writeToConsole $MSG_SAVING_FILE "$FILE_TO_INSTALL" "$newName"
		mv "$FILE_TO_INSTALL_ABS_FILE" "$newName" &>>"$LOG_FILE"
	elif (($REFRESH_SCRIPT)); then
		writeToConsole $MSG_NO_INSTALLATION_FOUND
		INSTALLATION_WARNING=1
		return
	fi

	if (($BETA_INSTALL)); then
		FILE_TO_INSTALL_URL="$BETA_CODE_URL"
		writeToConsole $MSG_DOWNLOADING_BETA "$FILE_TO_INSTALL"
	else
		FILE_TO_INSTALL_URL="$STABLE_CODE_URL"
		writeToConsole $MSG_DOWNLOADING "$FILE_TO_INSTALL"
	fi

	SCRIPT_INSTALLED=1

	httpCode=$(curl -s -o "/tmp/$FILE_TO_INSTALL" -m $DOWNLOAD_TIMEOUT -w %{http_code} -L "$MYHOMEURL/$FILE_TO_INSTALL_URL" 2>>"$LOG_FILE")
	if [[ ${httpCode:0:1} != "2" ]]; then
		writeToConsole $MSG_DOWNLOAD_FAILED "$FILE_TO_INSTALL" "$httpCode"
		unrecoverableError
	fi

	if ! mv "/tmp/$FILE_TO_INSTALL" "$FILE_TO_INSTALL_ABS_FILE" &>>"$LOG_FILE"; then
		writeToConsole $MSG_MOVE_FAILED "$FILE_TO_INSTALL_ABS_FILE"
		unrecoverableError
	fi

	writeToConsole $MSG_CODE_INSTALLED "$FILE_TO_INSTALL_ABS_FILE"

	if ! chmod 755 $FILE_TO_INSTALL_ABS_FILE &>>$LOG_FILE; then
		writeToConsole $MSG_CHMOD_FAILED "$FILE_TO_INSTALL_ABS_FILE"
		unrecoverableError
	fi

	if [[ "$MYDIR/$MYSELF" != "$FILE_TO_INSTALL_ABS_PATH/$MYSELF" ]]; then
		if [[ -n $RASPIBACKUP_INSTALL_DEBUG ]]; then
			if ! mv -f "$MYDIR/$MYSELF" "$FILE_TO_INSTALL_ABS_PATH" &>>"$LOG_FILE"; then
				writeToConsole $MSG_MOVE_FAILED "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"
				unrecoverableError
			fi
		else
			cp "$MYDIR/$MYSELF" "$FILE_TO_INSTALL_ABS_PATH" &>>"$LOG_FILE"
		fi
	fi

	writeToConsole $MSG_CODE_INSTALLED "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"

	if ! chmod 755 "$FILE_TO_INSTALL_ABS_PATH/$MYSELF" &>>"$LOG_FILE"; then
		writeToConsole $MSG_CHMOD_FAILED "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"
		unrecoverableError
	fi

	local chownArgs=$(stat -c "%U:%G" $FILE_TO_INSTALL_ABS_PATH | sed 's/\n//')
	if ! chown $chownArgs "$FILE_TO_INSTALL_ABS_PATH/$MYSELF" &>>"$LOG_FILE"; then
		writeToConsole $MSG_CHOWN_FAILED "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"
		unrecoverableError
	fi

}

config_download_execute() {

	log "config_download_execute"

	local newName http_code

	if [[ -f "$CONFIG_ABS_FILE" ]]; then
		oldVersion=$(grep -o -E "^VERSION=\".+\"" "$FILE_TO_INSTALL_ABS_FILE" | sed -e "s/VERSION=//" -e "s/\"//g")
		local m=${CONFIG_ABS_FILE##*/}
		n=${m%.*}
		newName="$n.$oldVersion.conf"
		writeToConsole $MSG_SAVING_FILE "$CONFIG_FILE" "$CONFIG_FILE_ABS_PATH/$newName"
		[[ "$FILE_TO_INSTALL_ABS_FILE" != "$newName" ]] && mv "$CONFIG_ABS_FILE" "$CONFIG_FILE_ABS_PATH/$newName" &>>"$LOG_FILE"
	fi

	writeToConsole $MSG_DOWNLOADING "$CONFIG_FILE"
	CONFIG_INSTALLED=1

	httpCode=$(curl -s -o $CONFIG_ABS_FILE -m $DOWNLOAD_TIMEOUT -w %{http_code} -L "$MYHOMEURL/$confFile" 2>>$LOG_FILE)
	if [[ ${httpCode:0:1} != "2" ]]; then
		writeToConsole $MSG_DOWNLOAD_FAILED "$confFile" "$httpCode"
		unrecoverableError
	fi

	if ! chmod 644 $CONFIG_ABS_FILE &>>$LOG_FILE; then
		writeToConsole $MSG_CHMOD_FAILED "$CONFIG_ABS_FILE"
		unrecoverableError
	fi

	writeToConsole $MSG_CODE_INSTALLED "$CONFIG_ABS_FILE"

}

extensions_install_do() {

	log "extensions_install_do"

	if ! isRaspiBackupInstalled; then
		local t=$(center $WINDOW_COLS "$RASPIBACKUP_NAME has to be installed first.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	if isExtensionInstalled; then
		local t=$(center $WINDOW_COLS "Extensions are already installed.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	INSTALL_DESCRIPTION=("Installing extensions ...")
	progressbar_do "INSTALL_DESCRIPTION" "Installing extensions" extensions_install_execute
}

extensions_install_execute() {

	log "extensions_install_execute"

	local extensions="mem temp disk"

	writeToConsole $MSG_DOWNLOADING "${SAMPLEEXTENSION_TAR_FILE%.*}"

	httpCode=$(curl -s -o $SAMPLEEXTENSION_TAR_FILE -m $DOWNLOAD_TIMEOUT -w %{http_code} -L "$MYHOMEURL/$SAMPLEEXTENSION_TAR_FILE" 2>>$LOG_FILE)
	if [[ ${httpCode:0:1} != "2" ]]; then
		writeToConsole $MSG_DOWNLOAD_FAILED "$SAMPLEEXTENSION_TAR_FILE" "$httpCode"
		unrecoverableError
	fi

	if ! tar -xzf "$SAMPLEEXTENSION_TAR_FILE" -C "$FILE_TO_INSTALL_ABS_PATH" &>>"$LOG_FILE"; then
		writeToConsole $MSG_SAMPLEEXTENSION_INSTALL_FAILED "tar -x"
		unrecoverableError
	fi

	if ! chmod 755 $FILE_TO_INSTALL_ABS_PATH/${RASPIBACKUP_NAME}_*.sh &>>"$LOG_FILE"; then
		writeToConsole $MSG_SAMPLEEXTENSION_INSTALL_FAILED "chmod extensions"
		unrecoverableError
	fi

	if ! rm -f "$SAMPLEEXTENSION_TAR_FILE" 2>>"$LOG_FILE"; then
		writeToConsole $MSG_UNINSTALL_FAILED "$SAMPLEEXTENSION_TAR_FILE"
		unrecoverableError
	fi

	sed -i "s/^DEFAULT_EXTENSIONS=.*\$/DEFAULT_EXTENSIONS=\"$extensions\"/" $CONFIG_ABS_FILE

	EXTENSIONS_INSTALLED=1

	writeToConsole $MSG_SAMPLEEXTENSION_INSTALL_SUCCESS

}

extensions_uninstall_do() {

	log "extensions_uninstall_do"

	if ! isExtensionInstalled; then
		local t=$(center $WINDOW_COLS "No extensions found.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	UNINSTALL_DESCRIPTION=("Uninstalling extensions ...")
	progressbar_do "UNINSTALL_DESCRIPTION" "Uninstalling extensions" extensions_uninstall_execute
}

extensions_uninstall_execute() {

	log "extensions_uninstall_execute"

	local extensions="mem temp disk"

	if ! rm -f $FILE_TO_INSTALL_ABS_PATH/${RASPIBACKUP_NAME}_*.sh &>>"$LOG_FILE"; then
		writeToConsole $MSG_SAMPLEEXTENSION_UNINSTALL_FAILED "rm extensions"
		unrecoverableError
	fi

	if [[ -f CONFIG_ABS_FILE ]]; then
		sed -i "s/^DEFAULT_EXTENSIONS=.*\$/DEFAULT_EXTENSIONS=\"\"/" $CONFIG_ABS_FILE
	fi

	EXTENSIONS_INSTALLED=0

	writeToConsole $MSG_SAMPLEEXTENSION_UNINSTALL_SUCCESS

}

config_update_execute() {

	log "config_update_execute"

	writeToConsole $MSG_UPDATING_CONFIG "$CONFIG_ABS_FILE"

	log "Language: $CONFIG_LANGUAGE"
	log "Mode: $CONFIG_PARTITIONBASED_BACKUPMSG_LEVEL"
	log "Type: $CONFIG_BACKUPTYPE"
	log "Zip: $CONFIG_ZIP_BACKUP"
	log "Keep: $CONFIG_KEEPBACKUPS"
	log "Msglevel: $CONFIG_MSG_LEVEL"

	sed -i "s/^DEFAULT_LANGUAGE=.*\$/DEFAULT_LANGUAGE=\"$CONFIG_LANGUAGE\"/" "$CONFIG_ABS_FILE"
	sed -i "s/^DEFAULT_PARTITIONBASED_BACKUP=.*\$/DEFAULT_PARTITIONBASED_BACKUP=\"$CONFIG_PARTITIONBASED_BACKUP\"/" "$CONFIG_ABS_FILE"
	sed -i "s/^DEFAULT_BACKUPTYPE=.*\$/DEFAULT_BACKUPTYPE=\"$CONFIG_BACKUPTYPE\"/" "$CONFIG_ABS_FILE"
	sed -i "s/^DEFAULT_ZIP_BACKUP=.*\$/DEFAULT_ZIP_BACKUP=\"$CONFIG_ZIP_BACKUP\"/" "$CONFIG_ABS_FILE"
	sed -i "s/^DEFAULT_KEEPBACKUPS=.*\$/DEFAULT_KEEPBACKUPS=\"$CONFIG_KEEPBACKUPS\"/" "$CONFIG_ABS_FILE"
	sed -i "s/^DEFAULT_MSG_LEVEL=.*$/DEFAULT_MSG_LEVEL=\"$CONFIG_MSG_LEVEL\"/" "$CONFIG_ABS_FILE"
}

cron_update_execute() {

	log "cron_update_execute"

	writeToConsole $MSG_UPDATING_CRON "$CRON_ABS_FILE"

	log "cron: $CONFIG_CRON_DAY $CONFIG_CRON_HOUR $CONFIG_CRON_MINUTE"

	local l="$(tail -n 1 < $CRON_ABS_FILE)"
	local disabled=""
	if ! isCrontabEnabled; then
		disabled="*"
	fi
	local v=$(awk -v disabled=$disabled -v minute=$CONFIG_CRON_MINUTE -v hour=$CONFIG_CRON_HOUR -v day=$CONFIG_CRON_DAY ' {print disabled minute, hour, $3, $4, day, $6, $7, $8}' <<< "$l")
	log "cron update: $v"
	local t=$(mktemp)
	head -n -1 "$CRON_ABS_FILE" > $t
	echo "$v" >> $t
	mv $t $CRON_ABS_FILE
	rm $t 2>/dev/null
}

cron_toggle_execute() {

	log "cron_toggle_execute"

	local l="$(tail -n 1 < $CRON_ABS_FILE))"
	local disabled
	if isCrontabEnabled; then
		disabled="#"
		log "Disable cron"
	else
		disabled=""
		log "Enable cron"
	fi
	local v=$(awk -v disabled=$disabled -v minute=$CONFIG_CRON_MINUTE -v hour=$CONFIG_CRON_HOUR -v day=$CONFIG_CRON_DAY ' {print disabled minute, hour, $3, $4, day, $6, $7, $8}' <<< "$l")
	local t=$(mktemp)
	head -n -1 "$CRON_ABS_FILE" > $t
	echo "$v" >> $t
	mv $t $CRON_ABS_FILE
	rm $t 2>/dev/null
}

cron_install_execute() {

	log "cron_install_execute"

	writeToConsole $MSG_INSTALLING_CRON_TEMPLATE "$CRON_ABS_FILE"
	echo "$CRON_CONTENTS" >"$CRON_ABS_FILE"
	CRON_INSTALLED=1

}

cron_uninstall_execute() {

	log "cron_deactivate_execute"

	writeToConsole $MSG_UNINSTALLING_CRON_TEMPLATE "$CRON_ABS_FILE"
	if ! rm -f "$CRON_ABS_FILE" 2>>"$LOG_FILE"; then
		writeToConsole $MSG_UNINSTALL_FAILED "$CRON_ABS_FILE"
		unrecoverableError
	fi
	CRON_INSTALLED=0

}

config_uninstall_execute() {

	log "config_uninstall_execute"

	local pre=${CONFIG_ABS_FILE%%.*}
	local post=${CONFIG_ABS_FILE##*.}

	writeToConsole $MSG_DELETE_FILE "$pre*.$post*"
	if ! rm -f $pre*.$post* &>>"$LOG_FILE"; then
		writeToConsole $MSG_UNINSTALL_FAILED "$pre*.$post*"
		unrecoverableError
	fi
}

uninstall_script_execute() {

	log "uninstall_script_execute"

	pre=${FILE_TO_INSTALL_ABS_FILE%%.*}
	post=${FILE_TO_INSTALL_ABS_FILE##*.}

	writeToConsole $MSG_DELETE_FILE "$pre*.$post*"
	if ! rm -f $pre*.$post* 2>>"$LOG_FILE"; then
		writeToConsole $MSG_UNINSTALL_FAILED "$pre*.$post*"
		unrecoverableError
	fi

	writeToConsole $MSG_DELETE_FILE "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"
	if ! rm -f "$FILE_TO_INSTALL_ABS_PATH/$MYSELF" 2>>$LOG_FILE; then
		writeToConsole $MSG_UNINSTALL_FAILED "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"
		unrecoverableError
	fi
}

uninstall_execute() {

	log "uninstall_execute"

	writeToConsole $MSG_DELETE_FILE "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"
	if ! rm -f "$FILE_TO_INSTALL_ABS_PATH/$MYSELF" 2>>$LOG_FILE; then
		writeToConsole $MSG_UNINSTALL_FAILED "$FILE_TO_INSTALL_ABS_PATH/$MYSELF"
		unrecoverableError
	fi

	writeToConsole $MSG_UNINSTALL_FINISHED "$RASPIBACKUP_NAME"

}

unrecoverableError() {
	local t=$(center $(($WINDOW_COLS * 2)) "Unrecoverable error occurred. Check logfile $LOG_FILE.")
	whiptail --msgbox "$t" $ROWS_MSGBOX 2
	exit 1
}

calc_wt_size() {

	# NOTE: it's tempting to redirect stderr to /dev/null, so supress error
	# output from tput. However in this case, tput detects neither stdout or
	# stderr is a tty and so only gives default 80, 24 values
	WT_HEIGHT=17
	WT_WIDTH=$(tput cols)

	if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
		WT_WIDTH=80
	fi
	if [ "$WT_WIDTH" -gt 178 ]; then
		WT_WIDTH=120
	fi
	WT_MENU_HEIGHT=$(($WT_HEIGHT - 7))
}

about_do() {

	log "about_do"

	local t=$(center $(($WINDOW_COLS * 2)) "This beta tool provides a straight-forward way of doing installation${NL}and initial basic configuration of $RASPIBACKUP_NAME.${NL}${NL}\
Visit https://www.linux-tips-and-tricks.de/en/ui-installer${NL}for details about custom installation and configuration of $RASPIBACKUP_NAME.")
	whiptail --msgbox "$t" $ROWS_ABOUT $(($WINDOW_COLS * 2)) 1
}

do_finish() {

	log "do_finish"

	exit 0
}

trapWithArg() { # function trap1 trap2 ... trapn
	local func="$1"
	shift
	for sig; do
		trap "$func $sig" "$sig"
	done
}

cleanup() {

	log "cleanup"

	trap '' SIGINT SIGTERM EXIT

	local rc=$?

	local signal="$1"

	TAIL=0
	if (($INSTALLATION_STARTED)); then
		if ((!$INSTALLATION_SUCCESSFULL)); then
			writeToConsole $MSG_CLEANUP
			(($CONFIG_INSTALLED)) && rm $CONFIG_ABS_FILE &>>"$LOG_FILE" || true
			(($SCRIPT_INSTALLED)) && rm $FILE_TO_INSTALL_ABS_FILE &>>"$LOG_FILE" || true
			(($CRON_INSTALLED)) && rm $CRON_ABS_FILE &>>"$LOG_FILE" || true
			(($EXTENSIONS_INSTALLED)) && rm -f $FILE_TO_INSTALL_ABS_PATH/${RASPIBACKUP_NAME}_*.sh &>>"$LOG_FILE" || true
			if [[ "$signal" == "SIGINT" ]]; then
				rm $LOG_FILE &>/dev/null || true
			else
				writeToConsole $MSG_INSTALLATION_FAILED "$RASPIBACKUP_NAME" "$LOG_FILE"
			fi
			rc=127
		else
			if ((!$INSTALLATION_WARNING)); then
				writeToConsole $MSG_INSTALLATION_FINISHED "$RASPIBACKUP_NAME"
			fi
			rm $LOG_FILE &>/dev/null || true
		fi
	fi

	(($EXTENSIONS_INSTALLED)) && rm $SAMPLEEXTENSION_TAR_FILE &>>$LOG_FILE || true

	exit $rc
}

config_menu() {

	log "config_menu"

	if ! isConfigInstalled; then
		local t=$(center $WINDOW_COLS "No $RASPIBACKUP_NAME configuration found.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	CONFIG_UPDATED=0
	CRON_UPDATED=0

	if isConfigInstalled; then
		log "Parsing config"
		IFS="" matches=$(grep -E "MSG_LEVEL|KEEPBACKUPS|BACKUPTYPE|ZIP_BACKUP|PARTITIONBASED_BACKUP|LANGUAGE" "$CONFIG_ABS_FILE")
		while IFS="=" read key value; do
			key=${key//\"/}
			key=${key/DEFAULT/CONFIG}
			value=${value//\"/}
			log "$key=$value"
			eval "$key=$value"
		done <<<"$matches"
	fi

	if isCrontabInstalled; then
		local l="$(tail -n 1 < $CRON_ABS_FILE))"
		log "last line: $l"
		local v=$(awk ' {print $1, $2, $5}' <<< "$l")
		log "parsed $v"
		CONFIG_CRON_MINUTE="$(cut -f 1 -d ' ' <<< $v)"
		[[ ${CONFIG_CRON_MINUTE:0:1} == "#" ]] && CONFIG_CRON_MINUTE="${CONFIG_CRON_MINUTE:1}"
		CONFIG_CRON_HOUR="$(cut -f 2 -d ' ' <<< $v)"
		CONFIG_CRON_DAY="$(cut -f 3 -d ' ' <<< $v)"
		log "parsed hour: $CONFIG_CRON_HOUR"
		log "parsed minute: $CONFIG_CRON_MINUTE"
		log "parsed day: $CONFIG_CRON_DAY"
	fi

	while :; do

		[[ $CONFIG_BACKUPTYPE == "dd" || $CONFIG_BACKUPTYPE == "tar" ]] && cp=("C6 Compress" "Compress backups") || cp=("" "")

		FUN=$(whiptail --title "$TITLE" --menu "Configuration" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
			"C1 Language" "Message language (English or German)" \
			"C2 Backupmode" "Backup all partitions (yes or no)" \
			"C3 Backuptype" "Linux backup tool used (dd, tar or rsync)" \
			"C4 Details" "Message verbosity (normal or detailed)" \
			"C5 Backups" "Number of backups to keep (1-52)" \
			"${cp[@]}" \
			"C7 eMail" "eMail notification configuration" \
			"C8 Backupday" "Weekday the backup is created (Mo-Sun)" \
			"C9 Backuphour" "Time the backup is created (00:00-23:59)" \
			3>&1 1>&2 2>&3)
		RET=$?
		if [ $RET -eq 1 ]; then
			if (($CONFIG_UPDATED || CRON_UPDATED)); then
				local t=$(center $WINDOW_COLS "Do you want to update configuration now ?")
				if whiptail --yesno "$t" --defaultno $ROWS_MSGBOX $WINDOW_COLS 1 3>&1 1>&2 2>&3; then
					if (( CONFIG_UPDATED )); then
						config_update_do
						CONFIG_UPDATED=0
					fi
					if (( CRON_UPDATED )); then
						cron_update_do
						CRON_UPDATED=0
					fi
				else
					local t=$(center $WINDOW_COLS "Changed configuration discarded.")
					whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
				fi
			fi
			return 0
		elif [ $RET -eq 0 ]; then
			log "configure_menu: Selected $FUN"
			case "$FUN" in
				C1\ *) config_language_do; CONFIG_UPDATED=$(( CONFIG_UPDATED|$? )) ;;
				C2\ *) config_backupmode_do; CONFIG_UPDATED=$(( CONFIG_UPDATED|$? )) ;;
				C3\ *) config_backuptype_do; CONFIG_UPDATED=$(( CONFIG_UPDATED|$? )) ;;
				C4\ *) config_message_detail_do; CONFIG_UPDATED=$(( CONFIG_UPDATED|$? )) ;;
				C5\ *) config_keep_do; CONFIG_UPDATED=$(( CONFIG_UPDATED|$? )) ;;
				C6\ *) config_compress_do; CONFIG_UPDATED=$(( CONFIG_UPDATED|$? )) ;;
				C7\ *) config_email_menu; CONFIG_UPDATED=$(( CONFIG_UPDATED|$? )) ;;
				C8\ *) config_cronday_do; CRON_UPDATED=$(( CRON_UPDATED|$? )) ;;
				C9\ *) config_crontime_do; CRON_UPDATED=$(( CRON_UPDATED|$? )) ;;
				"") : ;;
				*) whiptail --msgbox "Programm error: unrecognized option" $ROWS_MENU $WINDOW_COLS 1 ;;
			esac || whiptail --msgbox "There was an error running option $FUN" $ROWS_MENU $WINDOW_COLS 1
		fi
	done
}

config_email_menu() {

	log "config_email_menu"

	while :; do

		FUN=$(whiptail --title "$TITLE" --menu "Configuration" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
			"E1 eMail" "eMail address to send status eMail" \
			"E2 client" "eMail client to use" \
			3>&1 1>&2 2>&3)
		RET=$?
		local t=$(center $WINDOW_COLS "Option -${FUN}- will be implemented soon.")
		if [ $RET -eq 0 ]; then
			log "config_email_menu: Selected $FUN"
			case "$FUN" in
				E1\ *) email_address_do ;;
				E2\ *) email_client_do ;;
				*) whiptail --msgbox "Programm error: unrecognized option" $ROWS_MENU $WINDOW_COLS 1 ;;
#			esac || whiptail --msgbox "There was an error running option $FUN" $ROWS_MENU $WINDOW_COLS 1
			esac || whiptail --msgbox "$t" $ROWS_MENU $WINDOW_COLS 1
		else
			break
		fi
	done
}

config_keep_do() {

	log "config_keep_do"

	local current="$CONFIG_KEEPBACKUPS"

	while :; do
		ANSWER=$(whiptail --inputbox "Please enter number of backups to keep." $ROWS_MENU $WINDOW_COLS "$CONFIG_KEEPBACKUPS" 3>&1 1>&2 2>&3)
		if [ $? -eq 0 ]; then
			if [[ ! "$ANSWER" =~ ^[0-9]+$ ]] || (( "$ANSWER" >  52 )); then
				local t=$(center $WINDOW_COLS "Invalid input '$ANSWER'. Input has to be >= 1 and <= 52.")
				whiptail --msgbox "$t" $ROWS_MENU $WINDOW_COLS 2
			else
				CONFIG_KEEPBACKUPS="$ANSWER"
				break
			fi
		else
			break
		fi
	done

	[[ "$current" == "$CONFIG_KEEPBACKUPS" ]] && return 0 || return 1

}

config_crontime_do() {

	log "config_crontime_do"

	local current=$(printf "%02d:%02d" $CONFIG_CRON_HOUR $CONFIG_CRON_MINUTE)

	while :; do
		ANSWER=$(whiptail --inputbox "Please enter time of backup in format hh:mm." $ROWS_MENU $WINDOW_COLS "$current" 3>&1 1>&2 2>&3)
		if [ $? -eq 0 ]; then
			if [[ ! "$ANSWER" =~ ^[0-9]{1,2}:[0-9]{1,2}$ ]]; then
				local t=$(center $WINDOW_COLS "Invalid input '$ANSWER'. Input has to be in format hh:mm.")
				whiptail --msgbox "$t" $ROWS_MENU $WINDOW_COLS 2
			else
				CONFIG_CRON_HOUR=$(cut -f1 -d: <<< "$ANSWER")
				CONFIG_CRON_MINUTE=$(cut -f2 -d: <<< "$ANSWER")
				if (( CONFIG_CRON_HOUR > 23 || CONFIG_CRON_MINUTE > 59 )); then
					local t=$(center $WINDOW_COLS "Invalid input '$ANSWER'. Input has to be in format hh:mm where hh < 24 and mm < 60.")
					whiptail --msgbox "$t" $ROWS_MENU $WINDOW_COLS 2
				else
					log "hour: $CONFIG_CRON_HOUR minute: $CONFIG_CRON_MINUTE"
					break
				fi
			fi
		else
			break
		fi
	done

	[[ "$current" == "$CONFIG_CRON_HOUR:$CONFIG_CRON_MINUTE" ]] && return 0 || return 1

}

config_backuptype_do() {

	log "config_backuptype_do"

	local dd_=off
	local tar_=off
	local rsync_=off
	local current="$CONFIG_BACKUPTYPE"

	local dd=("dd" "Backup with dd. Backup can be restored on Windows." "$dd_")
	local cols=3
	if [[ $CONFIG_PARTITIONBASED_BACKUP == "p" ]]; then
		dd=("" "" "")
		cols=2
	fi

	case "$CONFIG_BACKUPTYPE" in
		dd) dd_=on ;;
		tar) tar_=on ;;
		rsync) rsync_=on ;;
	esac

	ANSWER=$(whiptail --radiolist "Choose backup type" $WT_HEIGHT $WT_WIDTH $cols \
		"rsync" "Backup with rsync and use hardlinks if possible." "$rsync_" \
		"tar" "Backup with tar." "$tar_" \
		${dd[@]} \
		3>&1 1>&2 2>&3)
	if [ $? -eq 0 ]; then
		case "$ANSWER" in
			dd)	CONFIG_BACKUPTYPE="dd" ;;
			tar) CONFIG_BACKUPTYPE="tar" ;;
			rsync) CONFIG_BACKUPTYPE="rsync" ;;
			*) whiptail --msgbox "Programm error, unrecognised backup type" $ROWS_MENU $WINDOW_COLS 2
				return 1 ;;
		esac
	fi

	[[ "$current" == "$CONFIG_BACKUPTYPE" ]] && return 0 || return 1
}

config_cronday_do() {

	log "config_cronday_do"

	local current="$CONFIG_CRON_DAY"
	local days_=(off off off off off off off)
	local daysShort=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
	local daysLong=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")

	days_[$CONFIG_CRON_DAY]=on

	ANSWER=$(whiptail --radiolist "Choose backup day of week" $WT_HEIGHT $(($WT_WIDTH/2)) 7 \
		"${daysShort[0]}" "${daysLong[0]}" "${days_[0]}" \
		"${daysShort[1]}" "${daysLong[1]}" "${days_[1]}" \
		"${daysShort[2]}" "${daysLong[2]}" "${days_[2]}" \
		"${daysShort[3]}" "${daysLong[3]}" "${days_[3]}" \
		"${daysShort[4]}" "${daysLong[4]}" "${days_[4]}" \
		"${daysShort[5]}" "${daysLong[5]}" "${days_[5]}" \
		"${daysShort[6]}" "${daysLong[6]}" "${days_[6]}" \
		3>&1 1>&2 2>&3)
	if [ $? -eq 0 ]; then
		CONFIG_CRON_DAY=$(cut -d/ -f1 <<< ${daysShort[@]/$ANSWER//} | wc -w | tr -d ' ')
	fi

	[[ "$current" == "$CONFIG_CRON_DAY" ]] && return 0 || return 1
}

config_compress_do() {

	log "config_compress_do"

	if [ $CONFIG_BACKUPTYPE == "rsync" ]; then
		local t=$(center $WINDOW_COLS "rsync backups cannot be compressed.")
		whiptail --msgbox "$t" $ROWS_MENU $WINDOW_COLS 2
	else
		local yes_=off
		local no_=off
		local current="$CONFIG_COMPRESS"

		case "$CONFIG_ZIP_BACKUP" in
			"1") yes_=on ;;
			"0") no_=on ;;
			*) whiptail --msgbox "Programm error, unrecognised compress mode" $ROWS_MENU $WINDOW_COLS 2
				return 1
				;;
		esac

		ANSWER=$(whiptail --radiolist "Compress backup" $WT_HEIGHT $(($WT_WIDTH/2)) 3 \
			"no" "Don't compress backup." "$no_" \
			"yes" "Compress backup." "$yes_" \
			3>&1 1>&2 2>&3)
		if [ $? -eq 0 ]; then
			case "$ANSWER" in
			no) CONFIG_ZIP_BACKUP="0" ;;
			yes) CONFIG_ZIP_BACKUP="1" ;;
			*) whiptail --msgbox "Programm error, unrecognised compress mode" $ROWS_MENU $WINDOW_COLS 2
				return 1
				;;
			esac
		fi
	fi

	[[ "$current" == "$CONFIG_COMPRESS" ]] && return 0 || return 1

}

progressbar_do() { # <name of description array> <menu title> <funcs to execute>

	log "progressbar_do"

	local descArrayName="$1"
	eval "$descArrayName+=(\"Done\")"
	shift
	local title="$1"
	shift
	declare todo=("${@}")
	todo+=("finished")
	num_todo=${#todo[*]}
	local step=$((100 / (num_todo - 1)))
	local idx=0
	local counter=0
	local desc
	(
		while
			:
			eval "desc=\${$descArrayName[\$idx]}"
		do
			cat <<EOF
XXX
$counter
$desc
XXX
EOF
			if ((idx < num_todo)); then
				${todo[$idx]}
			else
				break
			fi
			((idx += 1))
			((counter += step))
			sleep 2
		done
	) |
		whiptail --title "$title" --gauge "Please wait..." 6 70 0
}

uninstall_menu() {

	while :; do
		FUN=$(whiptail --title "$TITLE" --menu "Uninstallation" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
			"U1 $RASPIBACKUP_NAME" "Uninstall $RASPIBACKUP_NAME" \
			"U2 Extensions" "Uninstall and disable sample extensions" \
			3>&1 1>&2 2>&3)
		RET=$?
		if [ $RET -eq 1 ]; then
			return 0
		elif [ $RET -eq 0 ]; then
			log "uninstall_menu: Selected $FUN"
			case "$FUN" in
				U1\ *) uninstall_do ;;
				U2\ *) extensions_uninstall_do ;;
			*) whiptail --msgbox "Programm error: unrecognized option" $ROWS_MENU $WINDOW_COLS 1 ;;
			esac || whiptail --msgbox "There was an error running option $FUN" $ROWS_MENU $WINDOW_COLS 1
		fi
	done
}

update_menu() {

	while :; do
		FUN=$(whiptail --title "$TITLE" --menu "Upgrade" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
			"G1 $RASPIBACKUP_NAME" "Update $FILE_TO_INSTALL" \
			"G2 Installer" "Update $RASPIBACKUP_NAME installer" \
			3>&1 1>&2 2>&3)
		RET=$?
		local t=$(center $WINDOW_COLS "Option -${FUN}- will be implemented soon.")
		if [ $RET -eq 1 ]; then
			return 0
		elif [ $RET -eq 0 ]; then
			log "update_menu: Selected $FUN"
			case "$FUN" in
				G1\ *) update_script_do ;;
				G2\ *) update_installer_do ;;
				*) whiptail --msgbox "Programm error: unrecognized option" $ROWS_MENU $WINDOW_COLS 1 ;;
#			esac || whiptail --msgbox "There was an error running option $FUN" $ROWS_MENU $WINDOW_COLS 1
			esac || whiptail --msgbox "$t" $ROWS_MENU $WINDOW_COLS 1
		fi
	done
}


uninstall_do() {

	log "uninstall_do"

	if ! isRaspiBackupInstalled; then
		local t=$(center $WINDOW_COLS "$RASPIBACKUP_NAME is not installed.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	local t=$(center $WINDOW_COLS "Do you really want to uninstall $RASPIBACKUP_NAME ?")
	if ! whiptail --yesno "$t" --defaultno $ROWS_MSGBOX $WINDOW_COLS 2 3>&1 1>&2 2>&3; then
		return
	fi

	UNINSTALL_DESCRIPTION=("Deleting $RASPIBACKUP_NAME extensions ..." "Deleting $RASPIBACKUP_NAME cron configuration ..." "Deleting $RASPIBACKUP_NAME configurations ..."  "Deleting $FILE_TO_INSTALL ..." "Deleting $RASPIBACKUP_NAME installer ...")
	progressbar_do "UNINSTALL_DESCRIPTION" "Uninstalling $RASPIBACKUP_NAME" extensions_uninstall_execute cron_uninstall_execute config_uninstall_execute uninstall_script_execute uninstall_execute
}

install_menu() {

	while :; do
		FUN=$(whiptail --title "$TITLE" --menu "Installation" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
			"I1 $RASPIBACKUP_NAME" "Install $RASPIBACKUP_NAME with a default configuration" \
			"I2 Extensions" "Install and enable sample extensions" \
			3>&1 1>&2 2>&3)
		RET=$?
		if [ $RET -eq 1 ]; then
			return 0
		elif [ $RET -eq 0 ]; then
			log "install_menu: Selected $FUN"
			case "$FUN" in
				I1\ *) install_do ;;
				I2\ *) extensions_install_do ;;
				*) whiptail --msgbox "Programm error: unrecognized option" $ROWS_MENU $WINDOW_COLS 1 ;;
			esac || whiptail --msgbox "There was an error running option $FUN" $ROWS_MENU $WINDOW_COLS 1
		fi
	done
}

install_do() {

	log "install_do"

	if isRaspiBackupInstalled; then
		local t=$(center $WINDOW_COLS "$RASPIBACKUP_NAME already installed.${NL}Do you want to reinstall $RASPIBACKUP_NAME?")
		if ! whiptail --yesno "$t" $ROWS_MSGBOX $WINDOW_COLS 2; then
			return
		fi
	fi
	INSTALLATION_STARTED=1
	INSTALL_DESCRIPTION=("Downloading $FILE_TO_INSTALL ..." "Downloading $RASPIBACKUP_NAME configuration template ..." "Creating default $RASPIBACKUP_NAME configuration ..." "Installing $RASPIBACKUP_NAME cron config ...")
	progressbar_do "INSTALL_DESCRIPTION" "Installing $RASPIBACKUP_NAME" code_download_execute config_download_execute config_update_execute cron_install_execute
	INSTALLATION_SUCCESSFULL=1

}

config_download_do() {

	log "config_download_do"

	DOWNLOAD_DESCRIPTION=("Downloading $FILE_TO_INSTALL configuration ...")
	progressbar_do "DOWNLOAD_DESCRIPTION" "Downloading $FILE_TO_INSTALL configuration template" config_download_execute
}

config_update_do() {

	log "config_update_do"

	if ! isConfigInstalled; then
		local t=$(center $WINDOW_COLS "No configuration found.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	UPDATE_DESCRIPTION=("Updating $RASPIBACKUP_NAME configuration ...")
	progressbar_do "UPDATE_DESCRIPTION" "Updating $RASPIBACKUP_NAME configuration" config_update_execute
}

cron_update_do() {

	log "cron_update_do"

	if ! isCrontabInstalled; then
		local t=$(center $WINDOW_COLS "No crontab configuration found.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	UPDATE_DESCRIPTION=("Updating $RASPIBACKUP_NAME crontab configuration ...")
	progressbar_do "UPDATE_DESCRIPTION" "Updating $RASPIBACKUP_NAME crontab configuration" cron_update_execute
}

cron_toggle_do() {

	log "cron_toggle_do"

	if ! isCrontabInstalled; then
		local t=$(center $WINDOW_COLS "No crontab configuration found.")
		whiptail --msgbox "$t" $ROWS_MSGBOX $WINDOW_COLS 2
		return
	fi

	if isCrontabEnabled; then
		UPDATE_DESCRIPTION=("Disabling $RASPIBACKUP_NAME weekly backup ...")
	else
		UPDATE_DESCRIPTION=("Enabling $RASPIBACKUP_NAME weekly backup ...")
	fi
	progressbar_do "UPDATE_DESCRIPTION" "Updating cron configuration" cron_toggle_execute
}

config_backupmode_do() {

	log "config_backupmode_do"

	local normal_mode=off
	local partition_mode=off
	local current="$CONFIG_PARTITIONBASED_BACKUP"

	case "$CONFIG_PARTITIONBASED_BACKUP" in
		n) normal_mode=on ;;
		p) partition_mode=on ;;
		*)whiptail --msgbox "Programm error, unrecognised backup mode" $ROWS_MENU $WINDOW_COLS 2
			return 1
			;;
	esac

	ANSWER=$(whiptail --radiolist "Choose backup mode" $ROWS_MENU $WINDOW_COLS 2 \
		"Normal" "Backup 2 partions only" "$normal_mode" \
		"Partition" "Backup more than 2 partitions (no dd backuptype)" "$partition_mode" \
		3>&1 1>&2 2>&3)
	if [ $? -eq 0 ]; then
		case "$ANSWER" in
		Normal) CONFIG_PARTITIONBASED_BACKUP="n";;
		Partition) CONFIG_PARTITIONBASED_BACKUP="p" ;;
		*) whiptail --msgbox "Programm error, unrecognised backup mode" $ROWS_MENU $WINDOW_COLS 2
			return 1
			;;
		esac
	fi

	[[ "$current" == "$CONFIG_PARTITIONBASED_BACKUP" ]] && return 0 || return 1
}

config_message_detail_do() {

	log "config_message_detail_do"

	local detailed_=off
	local normal_=off
	local current="$CONFIG_MSG_LEVEL"

	case $CONFIG_MSG_LEVEL in
		"1") detailed_=on ;;
		"0") normal_=on ;;
		*)
			whiptail --msgbox "Programm error, unrecognised message level" $ROWS_MENU $WINDOW_COLS 2
			return 1
			;;
	esac

	ANSWER=$(whiptail --radiolist "Choose message verbosity" $ROWS_MENU $WINDOW_COLS 2 \
		"Normal" "Display important messages only" "$normal_" \
		"Verbose" "Display all messages" "$detailed_" \
		3>&1 1>&2 2>&3)
	if [ $? -eq 0 ]; then
		case "$ANSWER" in
			Normal) CONFIG_MSG_LEVEL="0";;
			Verbose) CONFIG_MSG_LEVEL="1" ;;
			*) whiptail --msgbox "Programm error, unrecognised message level" $ROWS_MENU $WINDOW_COLS 2
				return 1
				;;
		esac
	fi

	[[ "$current" == "$CONFIG_MSG_LEVEL" ]] && return 0 || return 1

}

config_language_do() {

	log "config_language_do"

	local en_=off
	local de_=off
	local current="$CONFIG_LANGUAGE"

	case "$CONFIG_LANGUAGE" in
		DE) de_=on ;;
		EN) en_=on ;;
		*)
			whiptail --msgbox "Programm error, unrecognised language" $ROWS_MENU $WINDOW_COLS 2
			return 1
			;;
	esac

	ANSWER=$(whiptail --radiolist "Choose language" $ROWS_MENU $WINDOW_COLS 2 \
		"en" "English" "$en_" \
		"de" "German" "$de_" \
		3>&1 1>&2 2>&3)
	if [ $? -eq 0 ]; then
		case "$ANSWER" in
		en) CONFIG_LANGUAGE="EN" ;;
		de) CONFIG_LANGUAGE="DE" ;;
		*)	whiptail --msgbox "Programm error, unrecognised language" $ROWS_MENU $WINDOW_COLS 2
			return 1
			;;
		esac
	fi

	[[ "$current" == "$CONFIG_LANGUAGE" ]] && return 0 || return 1

}

# Borrowed from http://blog.yjl.im/2012/01/printing-out-call-stack-in-bash.html

logStack() {
	local i=0
	local FRAMES=${#BASH_LINENO[@]}
	# FRAMES-2 skips main, the last one in arrays
	for ((i = FRAMES - 2; i >= 0; i--)); do
		echo '  File' \"${BASH_SOURCE[i + 1]}\", line ${BASH_LINENO[i]}, in ${FUNCNAME[i + 1]} >>"$LOG_FILE"
		# Grab the source code of the line
		sed -n "${BASH_LINENO[i]}{s/^/    /;p}" "${BASH_SOURCE[i + 1]}"
	done
}

error() {
	logStack
	cat "$LOG_FILE"
}

uiInstall() {
#
# Interactive use loop
#
calc_wt_size
while true; do

	ct=("3 Enable" "Enable weekly backup")
	if isCrontabInstalled; then
		if isCrontabEnabled; then
			ct=("3 Disable" "Disable weekly backup")
		fi
	fi

	FUN=$(whiptail --title "$TITLE" --menu "Selection option" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
		"1 Install" "Install $RASPIBACKUP_NAME components" \
		"2 Configure" "Configure major $RASPIBACKUP_NAME options" \
		"${ct[@]}" \
		"4 Update" "Update $FILE_TO_INSTALL or installer" \
		"5 Uninstall" "Uninstall $RASPIBACKUP_NAME components" \
		" " " " \
		"9 About" "Information about this installation tool" \
		3>&1 1>&2 2>&3)
	RET=$?
	if [ $RET -eq 1 ]; then
		if isCrontabInstalled; then
			if ! isCrontabEnabled; then
				local t=$(center $WINDOW_COLS "Would you like to enable weekly backup ?")
				if whiptail --yesno "$t" --defaultno $ROWS_MSGBOX $WINDOW_COLS 1 3>&1 1>&2 2>&3; then
					cron_toggle_do
				fi
			fi
		fi
		do_finish
	elif [ $RET -eq 0 ]; then
		log "Main: Selected $FUN"
		case "$FUN" in
			1\ *) install_menu ;;
			2\ *) config_menu ;;
			3\ *) cron_toggle_do ;;
			4\ *) update_menu ;;
			5\ *) uninstall_menu ;;
			9\ *) about_do ;;
			\ *) : ;;
			*) whiptail --msgbox "Programm error: unrecognized option" $ROWS_MENU $WINDOW_COLS 1 ;;
		esac || whiptail --msgbox "There was an error running option $FUN" $ROWS_MENU $WINDOW_COLS 1
	else
		exit 1
	fi
done
}

unattendedInstall() {
	if (( MODE_INSTALL )); then
		code_download_execute
		config_download_execute
		config_update_execute
		if (( MODE_EXTENSIONS )); then
			extensions_install_execute
		fi
	else
		extensions_uninstall_execute
		cron_uninstall_execute
		config_uninstall_execute
		uninstall_script_execute
		uninstall_execute
	fi
}

show_help() {
	echo $GIT_CODEVERSION
	echo "$MYSELF -i [ -e ]? | -u"
	echo "-i: unattended install of $RASPIBACKUP_NAME"
	echo "-u: unattended uninstall of $RASPIBACKUP_NAME"
	echo "-e: unattended install of $RASPIBACKUP_NAME extensions"
}

#trapWithArg error ERR
trapWithArg cleanup SIGINT SIGTERM EXIT

MODE_UNATTENDED=0
MODE_UNINSTALL=0
MODE_INSTALL=0
MODE_EXTENSIONS=0

while getopts "h?uei" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    i)  MODE_INSTALL=1
		MODE_UNATTENDED=1
        ;;
    e)  MODE_EXTENSIONS=1
		MODE_UNATTENDED=1
		;;
    u)  MODE_UNINSTALL=1
		MODE_UNATTENDED=1
		;;
	*)  echo "Unknown option $op"
		show_help
		exit 0
		;;
    esac
done

shift $((OPTIND-1))

writeToConsole $MSG_VERSION "$GIT_CODEVERSION"
TITLE="$RASPIBACKUP_NAME Installation and Configuration Tool $VERSION ($GIT_DATE_ONLY $GIT_TIME_ONLY - $GIT_COMMIT_ONLY)"

if (( MODE_UNATTENDED )); then
	unattendedInstall
else
	uiInstall
fi
