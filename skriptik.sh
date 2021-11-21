#!/bin/bash
function apache_install()
{
    if [ ! -f /apache_installed ]
    then
        # Install Apache HTTP Server.
        sudo yum install httpd -y
        sudo firewall-cmd --permanent --add-service=http --add-service=https -q
        sudo firewall-cmd --reload
        # Enable web server so it starts always after boot.
        sudo systemctl enable httpd.service
        # Start the service.
        sudo systemctl start http.service

        sudo touch /apache_installed
    else
        echo -e "Apache is already installed... "
    fi
}

function mariadb_install()
{
    if [ ! -f /mariadb_installed ]
    then
        # Install MariaDB Server.
        #wget https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
        curl -LsS -O https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
        sleep 5
        #chmod +x mariadb_repo_setup
        sudo bash mariadb_repo_setup --mariadb-server-version=10.6
        sudo sed -i 's/gpgcheck = 1/gpgcheck = 0/g' /etc/yum.repos.d/mariadb.repo
        sleep 5
        #sudo ./mariadb_repo_setup
        sudo yum install MariaDB-server MariaDB-client MariaDB-backup -y
        sleep 5
        #sudo yum install MariaDB-server -y
        sleep 5
        sudo systemctl enable mariadb.service
        sudo systemctl start mariadb.service
        sudo rm ./mariadb_repo_setup

        echo -e -n "Enter a password for a MariaDB root: "
        read -s root_password
        echo

        sleep .5
        sudo mariadb -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$root_password');"

        # Drop all the anonymous users.
        sudo mariadb -u "root" -p"$root_password" -e "DROP USER IF EXISTS ''@'localhost';"

        # Drop off the demo database.
        sudo mariadb -u "root" -p"$root_password" -e "DROP DATABASE IF EXISTS test;"

        # Make our changes take effect.
        sudo mariadb -u "root" -p"$root_password" -e "FLUSH PRIVILEGES;"

        ###############################################
        #                                             #
        #        Prepare MariaDB for Wordpress        #
        #                                             #
        ###############################################

        echo -e -n "Enter a password for a MariaDB wordpress_admin: "
        read -s wordpress_admin_password
        echo

        sudo mariadb -u "root" -p"$root_password" -e "CREATE DATABASE IF NOT EXISTS wordpress_db;"
        sudo mariadb -u "root" -p"$root_password" -e "CREATE USER IF NOT EXISTS wordpress_admin@'localhost' IDENTIFIED BY '$wordpress_admin_password';"
        sudo mariadb -u "root" -p"$root_password" -e "GRANT ALL PRIVILEGES ON wordpress_db.* TO wordpress_admin@'localhost' IDENTIFIED BY '$wordpress_admin_password';"
        sudo mariadb -u "root" -p"$root_password" -e "FLUSH PRIVILEGES;"

        sudo touch /mariadb_installed
    else
        echo -e "MariaDB is already installed..."
    fi
}

function php_install()
{
    if [ ! -f /php_installed ]
    then
        sudo yum install centos-release-scl.noarch -y
        sudo yum install rh-php72 rh-php72-php rh-php72-php-mysqlnd -y

        sudo ln -s /opt/rh/rh-php72/root/usr/bin/php /usr/bin/php

        if [ -f /apache_installed ] && [ ! -f /php_softlinks_configured ]
        then
            sudo ln -s /opt/rh/httpd24/root/etc/httpd/conf.d/rh-php72-php.conf /etc/httpd/conf.d/
            sudo ln -s /opt/rh/httpd24/root/etc/httpd/conf.modules.d/15-rh-php72-php.conf /etc/httpd/conf.modules.d/
            sudo ln -s /opt/rh/httpd24/root/etc/httpd/modules/librh-php72-php7.so /etc/httpd/modules/

            sudo systemctl restart httpd

            sudo touch /php_softlinks_configured
        else
            echo "Soft links were already created for php in /etc/httpd/{conf.d,conf.modules.d,modules}"
        fi

        sudo touch /php_installed
    else
        echo -e "PHP is already installed..."
    fi
}

function wordpress_install()
{
    if [ ! -f /wordpress_installed ] && [ -f /apache_installed ] && [ -f /mariadb_installed ] && [ -f /php_installed ]
    then
        cd ~
        wget http://wordpress.org/latest.tar.gz

        tar -xzvf latest.tar.gz

        sudo rsync -avP ~/wordpress/ /var/www/html/
        sudo mkdir /var/www/html/wp-content/uploads
        sudo chown -R apache:apache /var/www/html/*

        cd /var/www/html
        cp wp-config-sample.php wp-config.php

        echo -e -n "Password for wordpress_admin in MariaDB: "
        read -s wordpress_admin_password
        echo

        sudo sed -i 's/database_name_here/wordpress_db/g' /var/www/html/wp-config.php
        sudo sed -i 's/username_here/wordpress_admin/g' /var/www/html/wp-config.php
        sudo sed -i 's/password_here/'$wordpress_admin_password'/g' /var/www/html/wp-config.php

        sudo touch /wordpress_installed

        if [ -f /gui_installed ]
        then
            #firefox http://$(hostname)
            :
        fi
    else
        echo -e "Wordpress is already installed..."
    fi
}
