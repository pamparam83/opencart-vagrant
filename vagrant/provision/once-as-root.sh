#!/usr/bin/env bash

#== Import script args ==

timezone=$(echo "$1")

#== Bash helpers ==

function info {
  echo " "
  echo "--> $1"
  echo " "
}
base_domain="new.test"
apache_config_file="/etc/apache2/apache2.conf"
apache_vhost_file="/etc/apache2/sites-available/$base_domain.conf"

php_config_file="/etc/php/5.6/fpm/php.ini"
xdebug_config_file="/etc/php/5.6/mods-available/xdebug.ini"
mysql_config_file="/etc/mysql/my.cnf"
default_apache_index="/var/www/html/index.html"
project_web_root="public_html"
#== Provision script ==



info "Provision-script user: `whoami`"

export DEBIAN_FRONTEND=noninteractive

info "Configure timezone"
timedatectl set-timezone ${timezone} --no-ask-password

info "Prepare root password for MySQL"
debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password \"''\""
debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password \"''\""
echo "Done!"

info "Add PHp repository"
apt-get install python-software-properties
add-apt-repository ppa:ondrej/php -y

info "Update OS software"
apt-get update
apt-get dist-upgrade -y

apt-get install -y php5.6 php5.6-curl php5.6-mysql php5.6-zip php5.6-fpm php5.6-xml php5.6-gd php5.6-mbstring php5.6-mcrypt php5.6-cli php5.6-intl  php5.6-zip unzip  mysql-server-5.7

info "Install ionCube"
wget https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz
tar xzf ioncube_loaders_lin_x86-64.tar.gz
cp ioncube/ioncube_loader_lin_5.6.so /usr/lib/php/20131226/ioncube_loader.so
sed  -i "2i zend_extension = /usr/lib/php/20131226/ioncube_loader.so\n" ${php_config_file}

 Install Apache
info "Install Apache"
	apt-get -y install apache2 libapache2-mod-fastcgi

    a2enmod actions fastcgi alias proxy_fcgi

    sudo chmod -R 777 /var/www

	sed -i "s/^\(.*\)www-data/\1vagrant/g" ${apache_config_file}
	chown -R vagrant:vagrant /var/log/apache2

if [ ! -f "${apache_config_file}" ]; then
    cat << EOF > ${apache_config_file}
     <Directory /app/>
      Options Indexes FollowSymLinks
      AllowOverride None
      Require all granted
     </Directory> \n
EOF
fi

if [ ! -f "${apache_vhost_file}" ]; then
		cat << EOF > ${apache_vhost_file}
		Listen 80
		NameVirtualHost *:80
        <VirtualHost *:80>
            ServerAdmin webmaster@localhost
            ServerName $base_domain
            DocumentRoot /app/${project_web_root}
            LogLevel debug

            ErrorLog /var/log/apache2/error.log
            CustomLog /var/log/apache2/access.log combined

            <Directory /app/${project_web_root}>
                AllowOverride All
                Require all granted
            </Directory>
             <FilesMatch \.php$>
                # Apache 2.4.10+ can proxy to unix socket
                SetHandler "proxy:unix:/var/run/php/php5.6-fpm.sock|fcgi://localhost/"
            </FilesMatch>
        </VirtualHost>
EOF
	fi

	a2dissite 000-default
	a2ensite $base_domain
	a2enmod rewrite
    a2enmod $base_domain
	service apache2 reload
	update-rc.d apache2 enable

echo "Done!"

info "Install additional software"

sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${php_config_file}
sed -i "s/display_errors = Off/display_errors = On/g" ${php_config_file}

sudo sed -i "s/index.html/  index.php index.html/g" /etc/apache2/mods-available/dir.conf

if [ ! -f "{$xdebug_config_file}" ]; then
    cat << EOF > ${xdebug_config_file}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_host=10.0.2.2
EOF
	fi

 service apache2 reload
 systemctl restart apache2

echo "Done!"

#
info "Configure MySQL"
sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
mysql -uroot <<< "CREATE USER 'root'@'%' IDENTIFIED BY ''"
mysql -uroot <<< "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'"
mysql -uroot <<< "DROP USER 'root'@'localhost'"
mysql -uroot <<< "FLUSH PRIVILEGES"
echo "Done!"


info "Initailize databases for MySQL"
mysql -uroot <<< "CREATE DATABASE oc_shop CHARACTER SET utf8 COLLATE utf8_general_ci"
echo "Done!"

info "Install composer"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer


