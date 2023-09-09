#!/bin/bash
set -euo pipefail

install_service() {
	apt -yq install $1
}

restart_service() {
	systemctl restart $1 --no-pager
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
    C_DIR=$(pwd)
    if [ -d "linux-apache-mysql-php" ]; then
        cd linux-apache-mysql-php
        sudo bash lamp.sh --no-reboot
    else
        git clone https://github.com/nn-df/linux-apache-mysql-php.git
        cd linux-apache-mysql-php
        sudo bash lamp.sh --no-reboot
    fi
    cd ${C_DIR}

}

install_wordpress() {
    # download wordpress
    wget https://wordpress.org/latest.tar.gz

    # extract wordpress to new location
    sudo tar -xvf latest.tar.gz -C /var/www/

    # change wordpress to www-data user
    sudo chown -R www-data:www-data /var/www/wordpress

    echo "[+] Done config wordpress"
}

configure_apache() {
    # copy new configuration file
    cp apache/wordpress.conf /etc/apache2/sites-available/

    # disable default apache site
    sudo a2dissite 000-default

    # enable wordpress vhost
    sudo a2ensite wordpress

    # enable apache module
    sudo a2enmod rewrite

    # restart apache
    restart_service apache2

    echo "[+] Done config apache2"

}

configure_mysql() {
    # get database name
    DB_NAME=$(whiptail --title "Database Name" --inputbox "Database name : " 8 78 wordpress)
    if [ -z "${DB_NAME}" ]
        then
            echo "Error occur!! Database name is needed!"
        else
            :
    fi

    DB_PASS=$(whiptail --passwordbox "Database Password" --inputbox "Database password : " 8 78)
    if [ -z "${DB_PASS}" ]
        then
            echo "Error occur!! Password is needed!"
        else
            :
    fi

    # create db name
  	mysql -e "CREATE DATABASE ${DB_NAME};"

    # set password for db
   	mysql -e "CREATE USER wordpress@localhost IDENTIFIED BY '${DB_PASS}';"

    # grand user based on action
    mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,ALTER ON ${DB_NAME}.* TO wordpress@localhost;"

    # flush priviledges
    mysql -i "FLUSH PRIVILEGES;"
    
    # restart mysql
    restart_service mysql

    # configure wordpress config file
    sudo -u www-data cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
    # change db name
    sudo -u www-data sed -i 's/${DB_NAME}/wordpress/' /var/www/wordpress/wp-config.php
    # change db pass
    sudo -u www-data sed -i 's/${DB_PASS}/<your-password>/' /var/www/wordpress/wp-config.php

    echo "[+] Done config mysql"

}

main() {
    check_dependency
    install_dependency_wordpress
    install_wordpress
    configure_apache
    configure_mysql
}

main