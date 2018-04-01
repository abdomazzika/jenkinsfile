#!/bin/bash
set -x

### Geo ip database fetching
geoip_dir='/opt/GeoIP/share/GeoIP';
mkdir -p $geoip_dir;
wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz -O /tmp/GeoLite2-City.mmdb.gz;
gzip -d /tmp/GeoLite2-City.mmdb.gz;

mv /tmp/GeoLite2-City.mmdb $geoip_dir;

echo "This container will run those sidekiq queues: $Q"
echo "This container will run those kafka topics: $T"

concurrency=${C:-10}

eval "$(rbenv init -)"


#### Revisit this in case of any problems because of the high IO
#### writing to files !!
LOG_DIR=$(pwd)/log;
mkdir -p $LOG_DIR;

KAFKABP_LOG_FILE=${KAFKABP_LOG_FILE:-$LOG_DIR/kafkabp.log};
SIDEKIQ_LOG_FILE=${SIDEKIQ_LOG_FILE:-$LOG_DIR/sidekiq.log};

touch $KAFKABP_LOG_FILE;
touch $SIDEKIQ_LOG_FILE;

bundle exec kafkabp $T > $KAFKABP_LOG_FILE &
bundle exec sidekiq -t 8 \
                    -L $SIDEKIQ_LOG_FILE \
                    -e $RAILS_ENV \
                    -c $concurrency \
                    $Q
