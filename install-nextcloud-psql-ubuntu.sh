#########################################################
# Carsten Rieger IT-Services
# https://www.c-rieger.de
# https://github.com/criegerde
# INSTALL-NEXTCLOUD-PSQLUBUNTU.SH
# Version 1.0 (AMD64)
# Nextcloud 16
# OpenSSL 1.1.1, TLSv1.3, NGINX 1.15.x, PHP 7.3, PSQL11
# May, 05h 2019
#########################################################
# Ubuntu Bionic Beaver 18.04.x AMD64 - Nextcloud 16
#########################################################
#!/bin/bash
###global function to update and cleanup the environment
function update_and_clean() {
apt update
apt upgrade -y
apt autoclean -y
apt autoremove -y
}
###global function to restart all cloud services
function restart_all_services() {
/usr/sbin/service nginx restart
/usr/sbin/service postgresql restart
/usr/sbin/service redis-server restart
/usr/sbin/service php7.3-fpm restart
}
###global function to solve php-imagickexception as decribed here: https://www.c-rieger.de/solution-for-imagickexception-in-nextcloud-log
function phpimagickexception() {
/usr/sbin/service nginx stop
/usr/sbin/service php7.3-fpm stop
cp /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml.bak
sed -i "s/rights\=\"none\" pattern\=\"PS\"/rights\=\"read\|write\" pattern\=\"PS\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights\=\"none\" pattern\=\"EPI\"/rights\=\"read\|write\" pattern\=\"EPI\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights\=\"none\" pattern\=\"PDF\"/rights\=\"read\|write\" pattern\=\"PDF\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights\=\"none\" pattern\=\"XPS\"/rights\=\"read\|write\" pattern\=\"XPS\"/" /etc/ImageMagick-6/policy.xml
/usr/sbin/service nginx restart
/usr/sbin/service php7.3-fpm restart
}
###global function to scan Nextcloud data and generate an overview for fail2ban & ufw
function nextcloud_scan_data() {
sudo -u www-data php /var/www/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/nextcloud/occ files:scan-app-data
fail2ban-client status nextcloud
ufw status verbose
}
### START ###
cd /usr/local/src
###prepare the server environment
apt install gnupg2 wget -y
mv /etc/apt/sources.list /etc/apt/sources.list.bak && touch /etc/apt/sources.list
cat <<EOF >>/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu bionic main multiverse restricted universe
deb http://archive.ubuntu.com/ubuntu bionic-security main multiverse restricted universe
deb http://archive.ubuntu.com/ubuntu bionic-updates main multiverse restricted universe
deb http://ppa.launchpad.net/ondrej/php/ubuntu bionic main
deb http://ppa.launchpad.net/ondrej/nginx-mainline/ubuntu bionic main
deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main
EOF
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 4F4EA0AAE5267A6C
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
update_and_clean
apt install software-properties-common zip unzip screen curl git wget ffmpeg libfile-fcntllock-perl -y
###instal NGINX using TLSv1.3, OpenSSL 1.1.1
apt install nginx -y
###enable NGINX autostart
systemctl enable nginx.service
### prepare the NGINX
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak && touch /etc/nginx/nginx.conf
cat <<EOF >/etc/nginx/nginx.conf
user www-data;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
events {
worker_connections 1024;
multi_accept on;
use epoll;
}
http {
server_names_hash_bucket_size 64;
upstream php-handler {
server unix:/run/php/php7.3-fpm.sock;
}
include /etc/nginx/mime.types;
#include /etc/nginx/proxy.conf;
#include /etc/nginx/ssl.conf;
#include /etc/nginx/header.conf;
#include /etc/nginx/optimization.conf;
default_type application/octet-stream;
log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" \$status \$body_bytes_sent "\$http_referer" "\$http_user_agent" "\$http_x_forwarded_for" "\$host" sn="\$server_name" rt=\$request_time ua="\$upstream_addr" us="\$upstream_status" ut="\$upstream_response_time" ul="\$upstream_response_length" cs=\$upstream_cache_status' ;
access_log /var/log/nginx/access.log main;
sendfile on;
send_timeout 3600;
tcp_nopush on;
tcp_nodelay on;
open_file_cache max=500 inactive=10m;
open_file_cache_errors on;
keepalive_timeout 65;
reset_timedout_connection on;
server_tokens off;
resolver 127.0.0.53 valid=30s;
resolver_timeout 5s;
include /etc/nginx/conf.d/*.conf;
}
EOF
###restart NGINX
/usr/sbin/service nginx restart
###create folders
mkdir -p /var/nc_data /var/www/letsencrypt /usr/local/tmp/sessions /usr/local/tmp/apc
###apply permissions
chown -R www-data:www-data /var/nc_data /var/www
chown -R www-data:root /usr/local/tmp/sessions /usr/local/tmp/apc
###install PHP
apt install php7.3-fpm php7.3-gd php7.3-pgsql php7.3-curl php7.3-xml php7.3-zip php7.3-intl php7.3-mbstring php7.3-json php7.3-bz2 php7.3-ldap php-apcu imagemagick php-imagick -y
###adjust PHP
cp /etc/php/7.3/fpm/pool.d/www.conf /etc/php/7.3/fpm/pool.d/www.conf.bak
cp /etc/php/7.3/cli/php.ini /etc/php/7.3/cli/php.ini.bak
cp /etc/php/7.3/fpm/php.ini /etc/php/7.3/fpm/php.ini.bak
cp /etc/php/7.3/fpm/php-fpm.conf /etc/php/7.3/fpm/php-fpm.conf.bak
sed -i "s/;env\[HOSTNAME\] = /env[HOSTNAME] = /" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/;env\[TMP\] = /env[TMP] = /" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/;env\[TMPDIR\] = /env[TMPDIR] = /" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/;env\[TEMP\] = /env[TEMP] = /" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/;env\[PATH\] = /env[PATH] = /" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/pm.max_children = .*/pm.max_children = 240/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/pm.start_servers = .*/pm.start_servers = 20/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/pm.min_spare_servers = .*/pm.min_spare_servers = 10/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/pm.max_spare_servers = .*/pm.max_spare_servers = 20/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/;pm.max_requests = 500/pm.max_requests = 500/" /etc/php/7.3/fpm/pool.d/www.conf
sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/7.3/cli/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 1800/" /etc/php/7.3/cli/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/7.3/cli/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/7.3/cli/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/7.3/cli/php.ini
sed -i "s/max_file_uploads =.*/max_file_uploads = 100/" /etc/php/7.3/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = Europe\/\Berlin/" /etc/php/7.3/cli/php.ini
sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/7.3/cli/php.ini
sed -i "s/;session.save_path =.*/session.save_path = \"N;700;\/usr\/local\/tmp\/sessions\"/" /etc/php/7.3/cli/php.ini
sed -i '$aapc.enable_cli = 1' /etc/php/7.3/cli/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/7.3/fpm/php.ini
sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/7.3/fpm/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 1800/" /etc/php/7.3/fpm/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/7.3/fpm/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/7.3/fpm/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/7.3/fpm/php.ini
sed -i "s/max_file_uploads =.*/max_file_uploads = 100/" /etc/php/7.3/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = Europe\/\Berlin/" /etc/php/7.3/fpm/php.ini
sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/7.3/fpm/php.ini
sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/7.3/fpm/php.ini
sed -i "s/;opcache.enable_cli=.*/opcache.enable_cli=1/" /etc/php/7.3/fpm/php.ini
sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=128/" /etc/php/7.3/fpm/php.ini
sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/" /etc/php/7.3/fpm/php.ini
sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/" /etc/php/7.3/fpm/php.ini
sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/" /etc/php/7.3/fpm/php.ini
sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/7.3/fpm/php.ini
sed -i "s/;session.save_path =.*/session.save_path = \"N;700;\/usr\/local\/tmp\/sessions\"/" /etc/php/7.3/fpm/php.ini
sed -i "s/;emergency_restart_threshold =.*/emergency_restart_threshold = 10/" /etc/php/7.3/fpm/php-fpm.conf
sed -i "s/;emergency_restart_interval =.*/emergency_restart_interval = 1m/" /etc/php/7.3/fpm/php-fpm.conf
sed -i "s/;process_control_timeout =.*/process_control_timeout = 10s/" /etc/php/7.3/fpm/php-fpm.conf
sed -i '$aapc.enabled=1' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.file_update_protection=2' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.optimization=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.shm_size=256M' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.include_once_override=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.shm_segments=1' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.ttl=7200' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.user_ttl=7200' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.gc_ttl=3600' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.num_files_hint=1024' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.enable_cli=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.max_file_size=5M' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.cache_by_default=1' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.use_request_time=1' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.slam_defense=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.mmap_file_mask=/usr/local/tmp/apc/apc.XXXXXX' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.stat_ctime=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.canonicalize=1' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.write_lock=1' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.report_autofilter=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.rfc1867=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.rfc1867_prefix =upload_' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.rfc1867_name=APC_UPLOAD_PROGRESS' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.rfc1867_freq=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.rfc1867_ttl=3600' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.lazy_classes=0' /etc/php/7.3/fpm/php.ini
sed -i '$aapc.lazy_functions=0' /etc/php/7.3/fpm/php.ini
sed -i "s/09,39.*/# &/" /etc/cron.d/php
(crontab -l ; echo "09,39 * * * * /usr/lib/php/sessionclean 2>&1") | crontab -u root -
###modify /etc/fstab to use tmpfs
sed -i '$atmpfs /usr/local/tmp/apc tmpfs defaults,uid=33,size=300M,noatime,nosuid,nodev,noexec,mode=1777 0 0' /etc/fstab
sed -i '$atmpfs /usr/local/tmp/sessions tmpfs defaults,uid=33,size=300M,noatime,nosuid,nodev,noexec,mode=1777 0 0' /etc/fstab
###make use of tmpfs
mount -a
###restart PHP and NGINX
/usr/sbin/service php7.3-fpm restart
/usr/sbin/service nginx restart
###install MariaDB
mariadbinfo
apt update && apt install postgresql-11 -y
sudo -u postgres psql <<END
CREATE USER nextcloud WITH PASSWORD 'nextcloud';
CREATE DATABASE nextcloud WITH OWNER nextcloud TEMPLATE template0 ENCODING 'UTF8';
END
service postgresql stop
mv /etc/postgresql/11/main/postgresql.conf /etc/postgresql/11/main/postgresql.conf.bak && touch /etc/postgresql/11/main/postgresql.conf
cat <<EOF >/etc/postgresql/11/main/postgresql.conf
###################################################
# DB Version: 11 from c-rieger.de                 #
# OS Type: linux                                  #
# DB Type: web                                    #
# Total Memory (RAM): 2 GB                        #
# CPUs num: 2                                     #
# Data Storage: ssd                               #
# More information and tweaks can be found here:  #
# https://pgtune.leopard.in.ua/#/                 #
###################################################
checkpoint_completion_target = 0.7
cluster_name = '11/main'
data_directory = '/var/lib/postgresql/11/main'
datestyle = 'iso, mdy'
default_statistics_target = 100
default_text_search_config = 'pg_catalog.english'
dynamic_shared_memory_type = posix
effective_cache_size = 1536MB
effective_io_concurrency = 200
external_pid_file = '/var/run/postgresql/11-main.pid'
hba_file = '/etc/postgresql/11/main/pg_hba.conf'
ident_file = '/etc/postgresql/11/main/pg_ident.conf'
include_dir = 'conf.d'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'
log_line_prefix = '%m [%p] %q%u@%d '
log_timezone = 'UCT'
maintenance_work_mem = 128MB
max_wal_size = 2GB
max_connections = 200
max_worker_processes = 2
max_parallel_workers_per_gather = 1
max_parallel_workers = 2
min_wal_size = 1GB
port = 5432
random_page_cost = 1.1
ssl = on
ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
shared_buffers = 512MB
stats_temp_directory = '/var/run/postgresql/11-main.pg_stat_tmp'
timezone = 'UCT'
wal_buffers = 16MB
work_mem = 2621kB
unix_socket_directories = '/var/run/postgresql'
EOF
service postgresql restart && service php7.3-fpm restart
update_and_clean
###install Redis-Server
apt install redis-server php-redis -y
cp /etc/redis/redis.conf /etc/redis/redis.conf.bak
sed -i "s/port 6379/port 0/" /etc/redis/redis.conf
sed -i s/\#\ unixsocket/\unixsocket/g /etc/redis/redis.conf
sed -i "s/unixsocketperm 700/unixsocketperm 770/" /etc/redis/redis.conf
sed -i "s/# maxclients 10000/maxclients 512/" /etc/redis/redis.conf
usermod -a -G redis www-data
cp /etc/sysctl.conf /etc/sysctl.conf.bak && sed -i '$avm.overcommit_memory = 1' /etc/sysctl.conf
###install self signed certificates
apt install ssl-cert -y
###prepare NGINX for Nextcloud and SSL
[ -f /etc/nginx/conf.d/default.conf ] && mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
touch /etc/nginx/conf.d/default.conf
cat <<EOF >/etc/nginx/conf.d/nextcloud.conf
server {
server_name YOUR.DEDYN.IO;
listen 80 default_server;
location ^~ /.well-known/acme-challenge {
proxy_pass http://127.0.0.1:81;
proxy_set_header Host \$host;
}
location / {
return 301 https://\$host\$request_uri;
}
}
server {
server_name YOUR.DEDYN.IO;
listen 443 ssl http2 default_server;
root /var/www/nextcloud/;
access_log /var/log/nginx/nextcloud.access.log main;
error_log /var/log/nginx/nextcloud.error.log warn;
location = /robots.txt {
allow all;
log_not_found off;
access_log off;
}
location = /.well-known/carddav {
return 301 \$scheme://\$host/remote.php/dav;
}
location = /.well-known/caldav {
return 301 \$scheme://\$host/remote.php/dav;
}
#SOCIAL app enabled? Please uncomment the following three rows
#rewrite ^/.well-known/webfinger /nextcloud/public.php?service=webfinger last;
#rewrite ^/.well-known/host-meta /nextcloud/public.php?service=host-meta last;
#rewrite ^/.well-known/host-meta.json /nextcloud/public.php?service=host-meta-json last;
client_max_body_size 10240M;
location / {
rewrite ^ /index.php\$request_uri;
}
location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
deny all;
}
location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
deny all;
}
location ~ ^/(?:index|remote|public|cron|core/ajax/update|status|ocs/v[12]|updater/.+|ocs-provider/.+)\.php(?:\$|/) {
fastcgi_split_path_info ^(.+\.php)(/.*)\$;
include fastcgi_params;
include php_optimization.conf;
fastcgi_pass php-handler;
fastcgi_param HTTPS on;
}
location ~ ^/(?:updater|ocs-provider)(?:\$|/) {
try_files \$uri/ =404;
index index.php;
}
location ~ \.(?:css|js|woff2?|svg|gif|png|html|ttf|ico|jpg|jpeg)\$ {
try_files \$uri /index.php\$request_uri;
access_log off;
expires 360d;
}
}
EOF
###create a Let's Encrypt vhost file
touch /etc/nginx/conf.d/letsencrypt.conf
cat <<EOF >/etc/nginx/conf.d/letsencrypt.conf
server {
server_name 127.0.0.1;
listen 127.0.0.1:81 default_server;
charset utf-8;
access_log /var/log/nginx/le.access.log main;
error_log /var/log/nginx/le.error.log warn;
location ^~ /.well-known/acme-challenge {
default_type text/plain;
root /var/www/letsencrypt;
}
}
EOF
###create a ssl configuration file
touch /etc/nginx/ssl.conf
cat <<EOF >/etc/nginx/ssl.conf
ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
ssl_trusted_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
#ssl_certificate /etc/letsencrypt/live/YOUR.DEDYN.IO/fullchain.pem;
#ssl_certificate_key /etc/letsencrypt/live/YOUR.DEDYN.IO/privkey.pem;
#ssl_trusted_certificate /etc/letsencrypt/live/YOUR.DEDYN.IO/chain.pem;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;
ssl_protocols TLSv1.3 TLSv1.2;
ssl_ciphers 'TLS-CHACHA20-POLY1305-SHA256:TLS-AES-256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384'; #:ECDHE-RSA-AES256-SHA384';
ssl_ecdh_curve X448:secp521r1:secp384r1;
ssl_prefer_server_ciphers on;
ssl_stapling on;
ssl_stapling_verify on;
EOF
###add a default dhparam.pem file // https://wiki.mozilla.org/Security/Server_Side_TLS#ffdhe4096
touch /etc/ssl/certs/dhparam.pem
cat <<EOF >/etc/ssl/certs/dhparam.pem
-----BEGIN DH PARAMETERS-----
MIICCAKCAgEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEfz9zeNVs7ZRkDW7w09N75nAI4YbRvydbmyQd62R0mkff3
7lmMsPrBhtkcrv4TCYUTknC0EwyTvEN5RPT9RFLi103TZPLiHnH1S/9croKrnJ32
nuhtK8UiNjoNq8Uhl5sN6todv5pC1cRITgq80Gv6U93vPBsg7j/VnXwl5B0rZp4e
8W5vUsMWTfT7eTDp5OWIV7asfV9C1p9tGHdjzx1VA0AEh/VbpX4xzHpxNciG77Qx
iu1qHgEtnmgyqQdgCpGBMMRtx3j5ca0AOAkpmaMzy4t6Gh25PXFAADwqTs6p+Y0K
zAqCkc3OyX3Pjsm1Wn+IpGtNtahR9EGC4caKAH5eZV9q//////////8CAQI=
-----END DH PARAMETERS-----
EOF
###create a proxy configuration file
touch /etc/nginx/proxy.conf
cat <<EOF >/etc/nginx/proxy.conf
proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-Host \$host;
proxy_set_header X-Forwarded-Protocol \$scheme;
proxy_set_header X-Forwarded-For \$remote_addr;
proxy_set_header X-Forwarded-Port \$server_port;
proxy_set_header X-Forwarded-Server \$host;
proxy_connect_timeout 3600;
proxy_send_timeout 3600;
proxy_read_timeout 3600;
proxy_redirect off;
EOF
###create a header configuration file
touch /etc/nginx/header.conf
cat <<EOF >/etc/nginx/header.conf
add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
add_header X-Robots-Tag none;
add_header X-Download-Options noopen;
add_header X-Permitted-Cross-Domain-Policies none;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer" always;
#add_header Feature-Policy "accelerometer 'none'; autoplay 'self'; geolocation 'none'; midi 'none'; sync-xhr 'self' ; microphone 'self'; camera 'self'; magnetometer 'none'; gyroscope 'none'; speaker 'self'; fullscreen 'self'; payment 'none'; usb 'none'";                                                                                   
EOF
###create a nginx optimization file
touch /etc/nginx/optimization.conf
cat <<EOF >/etc/nginx/optimization.conf
fastcgi_read_timeout 3600;
fastcgi_buffers 64 64K;
fastcgi_buffer_size 256k;
fastcgi_busy_buffers_size 3840K;
fastcgi_cache_key \$http_cookie$request_method$host$request_uri;
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
gzip on;
gzip_vary on;
gzip_comp_level 4;
gzip_min_length 256;
gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
gzip_disable "MSIE [1-6]\.";
EOF
###create a nginx php optimization file
touch /etc/nginx/php_optimization.conf
cat <<EOF >/etc/nginx/php_optimization.conf
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
fastcgi_param PATH_INFO \$fastcgi_path_info;
fastcgi_param modHeadersAvailable true;
fastcgi_param front_controller_active true;
fastcgi_intercept_errors on;
fastcgi_request_buffering off;
fastcgi_cache_valid 404 1m;
fastcgi_cache_valid any 1h;
fastcgi_cache_methods GET HEAD;
EOF
###enable all nginx configuration files
sed -i s/\#\include/\include/g /etc/nginx/nginx.conf
###enable all nginx configuration files
sed -i "s/server_name YOUR.DEDYN.IO;/server_name $(hostname);/" /etc/nginx/conf.d/nextcloud.conf
###create Nextclouds cronjob
(crontab -u www-data -l ; echo "*/5 * * * * php -f /var/www/nextcloud/cron.php > /dev/null 2>&1") | crontab -u www-data -
###restart NGINX
service nginx restart
###Download Nextclouds latest release and extract it
# wget https://download.nextcloud.com/server/releases/latest.tar.bz2
wget https://download.nextcloud.com/server/releases/nextcloud-16.0.0.tar.bz2
tar -xjf nextcloud-*.tar.bz2 -C /var/www
###apply permissions
chown -R www-data:www-data /var/www/
###remove the Nextcloud sources
rm -f nextcloud-*.tar.bz2
###update and restart all sources and services
update_and_clean
restart_all_services
clear
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo "Nextcloud-Administrator and password - Attention: password is case-sensitive:"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "Your Nextcloud-DB user: nextcloud"
echo ""
echo "Your Nextcloud-DB password: nextcloud"
echo ""
read -p "Enter your Nextcloud Administrator: " NEXTCLOUDADMINUSER
echo "Your Nextcloud Administrator: "$NEXTCLOUDADMINUSER
echo ""
read -p "Enter your Nextcloud Administrator password: " NEXTCLOUDADMINUSERPASSWORD
echo "Your Nextcloud Administrator password: "$NEXTCLOUDADMINUSERPASSWORD
echo ""
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "Your NEXTCLOUD will now be installed silently - please be patient ..."
echo ""
###NEXTCLOUD INSTALLATION
sudo -u www-data php /var/www/nextcloud/occ maintenance:install --database "pgsql" --database-name "nextcloud"  --database-user "nextcloud" --database-pass "nextcloud" --admin-user "$NEXTCLOUDADMINUSER" --admin-pass "$NEXTCLOUDADMINUSERPASSWORD" --data-dir "/var/nc_data"
###read and store the current hostname in lowercases
declare -l YOURSERVERNAME
YOURSERVERNAME=$(hostname)
###Modifications to Nextclouds config.php
sudo -u www-data cp /var/www/nextcloud/config/config.php /var/www/nextcloud/config/config.php.bak
sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 0 --value=$YOURSERVERNAME
sudo -u www-data php /var/www/nextcloud/occ config:system:set overwrite.cli.url --value=https://$YOURSERVERNAME
echo ""
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
###backup of the effected file .user.ini
cp /var/www/nextcloud/.user.ini /usr/local/src/.user.ini.bak
###apply Nextcloud optimizations
sudo -u www-data sed -i "s/upload_max_filesize=.*/upload_max_filesize=10240M/" /var/www/nextcloud/.user.ini
sudo -u www-data sed -i "s/post_max_size=.*/post_max_size=10240M/" /var/www/nextcloud/.user.ini
sudo -u www-data sed -i "s/output_buffering=.*/output_buffering='Off'/" /var/www/nextcloud/.user.ini
sudo -u www-data php /var/www/nextcloud/occ background:cron
###apply optimizations to Nextclouds global config.php
sed -i '/);/d' /var/www/nextcloud/config/config.php
cat <<EOF >>/var/www/nextcloud/config/config.php
'activity_expire_days' => 14,
'auth.bruteforce.protection.enabled' => true,
'blacklisted_files' =>
array (
0 => '.htaccess',
1 => 'Thumbs.db',
2 => 'thumbs.db',
),
'cron_log' => true,
'enable_previews' => true,
'enabledPreviewProviders' =>
array (
0 => 'OC\\Preview\\PNG',
1 => 'OC\\Preview\\JPEG',
2 => 'OC\\Preview\\GIF',
3 => 'OC\\Preview\\BMP',
4 => 'OC\\Preview\\XBitmap',
5 => 'OC\\Preview\\Movie',
6 => 'OC\\Preview\\PDF',
7 => 'OC\\Preview\\MP3',
8 => 'OC\\Preview\\TXT',
9 => 'OC\\Preview\\MarkDown',
),
'filesystem_check_changes' => 0,
'filelocking.enabled' => 'true',
'htaccess.RewriteBase' => '/',
'integrity.check.disabled' => false,
'knowledgebaseenabled' => false,
'log_rotate_size' => 104857600,
'logfile' => '/var/nc_data/nextcloud.log',
'logtimezone' => 'Europe/Berlin',
'memcache.local' => '\\OC\\Memcache\\APCu',
'memcache.locking' => '\\OC\\Memcache\\Redis',
'preview_max_x' => 1024,
'preview_max_y' => 768,
'preview_max_scale_factor' => 1,
'redis' =>
array (
'host' => '/var/run/redis/redis-server.sock',
'port' => 0,
'timeout' => 0.0,
),
'quota_include_external_storage' => false,
'share_folder' => '/Shares',
'skeletondirectory' => '',
'trashbin_retention_obligation' => 'auto, 7',
);
EOF
###remove leading whitespaces
sed -i 's/^[ ]*//' /var/www/nextcloud/config/config.php
restart_all_services
update_and_clean
###install fail2ban
apt install fail2ban -y
###create a fail2ban Nextcloud filter
touch /etc/fail2ban/filter.d/nextcloud.conf
cat <<EOF >/etc/fail2ban/filter.d/nextcloud.conf
[Definition]
failregex=^{"reqId":".*","remoteAddr":".*","app":"core","message":"Login failed: '.*' \(Remote IP: '<HOST>'\)","level":2,"time":".*"}$
            ^{"reqId":".*","level":2,"time":".*","remoteAddr":".*","app":"core".*","message":"Login failed: '.*' \(Remote IP: '<HOST>'\)".*}$
            ^.*\"remoteAddr\":\"<HOST>\".*Trusted domain error.*\$
EOF
###create a fail2ban Nextcloud jail
touch /etc/fail2ban/jail.d/nextcloud.local
cat <<EOF >/etc/fail2ban/jail.d/nextcloud.local
[nextcloud]
backend = auto
enabled = true
port = 80,443
protocol = tcp
filter = nextcloud
maxretry = 3
bantime = 36000
findtime = 36000
logpath = /var/nc_data/nextcloud.log
[nginx-http-auth]
enabled = true
EOF
update_and_clean
###install ufw
apt install ufw -y
###open firewall ports 80+443 for http(s)
ufw allow 80/tcp
ufw allow 443/tcp
###open firewall port 22 for SSH
ufw allow 22/tcp
###enable UFW (autostart)
ufw logging medium && ufw default deny incoming && ufw enable
###restart fail2ban, ufw and redis-server services
/usr/sbin/service ufw restart
/usr/sbin/service fail2ban restart
/usr/sbin/service redis-server restart
###enable audit and pdf apps
sudo -u www-data php /var/www/nextcloud/occ app:enable admin_audit
sudo -u www-data php /var/www/nextcloud/occ app:enable files_pdfviewer
###clean up redis-server
redis-cli -s /var/run/redis/redis-server.sock <<EOF
FLUSHALL
quit
EOF
###Nextcloud occ db:... (maintenance/optimization)
/usr/sbin/service nginx stop
clear
echo "---------------------------------"
echo "Issue Nextcloud-DB optimizations!"
echo "---------------------------------"
echo "Press 'y' to issue optimizations."
echo "---------------------------------"
echo ""
sudo -u www-data php /var/www/nextcloud/occ db:add-missing-indices
sudo -u www-data php /var/www/nextcloud/occ db:convert-filecache-bigint
###solve an issue with phpimagick
phpimagickexception
###rescan Nextcloud data
nextcloud_scan_data
restart_all_services
### issue the cron.php once
sudo -u www-data php /var/www/nextcloud/cron.php
clear
echo ""
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo " Open your browser and call your Nextcloud at"
echo ""
echo " https://$YOURSERVERNAME"
echo ""
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo " I do strongly recommend to enhance the server security by re-creating"
echo " the dhparam.pem file:"
echo ""
echo " openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096"
echo ""
echo " https://www.c-rieger.de/nextcloud-installation-guide-ubuntu/#dhparamfile"
echo ""
echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
### CleanUp
cat /dev/null > ~/.bash_history && history -c && history -w
exit 0
