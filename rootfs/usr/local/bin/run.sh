#!/bin/sh

# Apply environment variables settings
sed -i -e "s/<APC_SHM_SIZE>/$APC_SHM_SIZE/g" /usr/local/etc/php/conf.d/apcu.ini \
       -e "s/<OPCACHE_MEM_SIZE>/$OPCACHE_MEM_SIZE/g" /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
       -e "s/<CRON_MEMORY_LIMIT>/$CRON_MEMORY_LIMIT/g" /etc/s6.d/cron/run \
       -e "s/<CRON_PERIOD>/$CRON_PERIOD/g" /etc/s6.d/cron/run \
       -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" /usr/local/bin/occ \
       -e "s/<UPLOAD_MAX_SIZE>/$UPLOAD_MAX_SIZE/g" /etc/nginx/nginx.conf /usr/local/etc/php-fpm.conf \
       -e "s/<MEMORY_LIMIT>/$MEMORY_LIMIT/g" /usr/local/etc/php-fpm.conf

# If new install, run setup
if [ ! -f /nextcloud/config/config.php ]; then
    touch /nextcloud/config/CAN_INSTALL
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

# Run processes
exec /bin/s6-svscan /etc/s6.d
