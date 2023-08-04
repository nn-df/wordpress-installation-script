#!/bin/bash
set -euo pipefail

install_service() {
	apt -yq install $1
}

check_service_status() {
	systemctl status $1 --no-pager
}

cmd_reboot() {
	whiptail --title "Reboting..." --msgbox "This server will reboot in 5 seconds" 8 78
	sleep 5
	reboot
}


check_dependency() {
	# check root
	if [[ $EUID -ne 0 ]]; then
	   echo "[!] This script must be run as root" 
	   exit 1
	fi

	# check network status (internet and dns)
	if ping -q -c 3 -W 1 www.google.com > /dev/null 2>&1;then
		echo "[+] Checking network OK"
	else 
		if ping -q -c 3 -W 1 8.8.8.8 > /dev/null 2>&1;then
			echo "[!] Check your DNS setting"
			exit $?
		else
			echo "[!] Check your NETWORK setting"
			exit $?
		fi
	fi

	# check whiptail
	if which whiptail > /dev/null 2>&1; then
		echo "[+] Checking whiptail OK"
		:
	else
		install_service whiptail
	fi
	
}

install_dependency_wordpress() {
    # require of LAMP stack, will used other repo to cover on this part
    git clone https://github.com/nn-df/linux-apache-mysql-php.git
    cd linux-apache-mysql-php
    sudo bash lamp.sh --no-reboot

}

main() {
    check_dependency
    install_dependency_wordpress

}

main