#!/bin/sh

sed -i -e "s/<APC_SHM_SIZE>/$APC_SHM_SIZE/g" /php/conf.d/apcu.ini \
       -e "s/<OPCACHE_MEM_SIZE>/$OPCACHE_MEM_SIZE/g" /php/conf.d/opcache.ini \
       -e "s/<CRON_MEMORY_LIMIT>/$CRON_MEMORY_LIMIT/g" /etc/s6.d/cron/run \
       -e "s/<CRON_PERIOD>/$CRON_PERIOD/g" /etc/s6.d/cron/run \
       -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" /usr/local/bin/occ \
       -e "s/<UPLOAD_MAX_SIZE>/$UPLOAD_MAX_SIZE/g" /nginx/conf/nginx.conf /php/etc/php-fpm.conf \
       -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" /php/etc/php-fpm.conf

# Put the configuration and apps into volumes
ln -sf /config/config.php /nextcloud/config/config.php &>/dev/null
ln -sf /apps2 /nextcloud &>/dev/null
chown -h $UID:$GID /nextcloud/config/config.php /nextcloud/apps2

# Create folder for php sessions if not exists
if [ ! -d /data/session ]; then
  mkdir -p /data/session;
fi

echo "Updating permissions..."
for dir in /nextcloud /data /config /apps2 /var/log /php /nginx /tmp /etc/s6.d; do
  if $(find $dir ! -user $UID -o ! -group $GID|egrep '.' -q); then
    echo "Updating permissions in $dir..."
    chown -R $UID:$GID $dir
  else
    echo "Permissions in $dir are correct."
  fi
done
echo "Done updating permissions."

echo "Check for UserId ${UID}"
grep ":${UID}:" /etc/passwd 1>/dev/null 2>&1
ERRORCODE=$?

if [ $ERRORCODE -ne 0 ]; then
   echo "Creating user nextcloud with UID=${UID} and GID=${GID}"
   /usr/sbin/adduser -g ${GID} -u ${UID} --disabled-password  --gecos "" nextcloud
else
   echo "An existing user with UID=${UID} was found, nothing to do"
fi

if [ ! -f /config/config.php ]; then
    # New installation, run the setup
    /usr/local/bin/setup.sh
else
    # Run upgrade if applicable
    echo "Running occ upgrade..."
    occ upgrade -vv
    echo "occ upgrade finished."

		# Add missing columns
		echo "Running occ db:add-missing-columns..."
		occ db:add-missing-columns
		echo "occ db:add-missing-columns finished."

    # Add missing indexes
    echo "Running occ db:add-missing-indices ..."
    occ db:add-missing-indices
    echo "occ db:add-missing-indices finished."

		# Add missing columns
		echo "Running occ db:add-missing-columns..."
    occ db:add-missing-columns
    echo "occ db:add-missing-columns finished."

		# Add missing primary keys
		echo "Running occ db:add-missing-primary-keys..."
    occ db:add-missing-primary-keys
    echo "occ db:db:add-missing-primary-keys finished."

		echo ""
    echo "Done running upgrade scripts! Now starting up nextcloud..."
    echo ""
fi

exec su-exec $UID:$GID /bin/s6-svscan /etc/s6.d
