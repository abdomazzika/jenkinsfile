#!/bin/bash

# sync new migrations
echo -e "\n\e[1m\e[44m Migrating database..... \e[0m\n"
bin/rake db:migrate;
bin/rake assets:precompile;

if [ -z "$RDS_RO_HOSTNAME"]; then
  # Only read/write enabled master mysql need to be operated on by cron jobs
  bin/bundle exec whenever --set "environment=$RACK_ENV" --update-crontab
fi

# We need to keep the environment variables for cron to capture
env | xargs -n 1 echo "export " >> $HOME/.profile;
if [ -n "$GOREPLAY" ] && [ -n "$GOREPLAY_HOST" ];then
    wget https://github.com/buger/goreplay/releases/download/v0.16.1/gor_0.16.1_x64.tar.gz;
    tar xzvf gor_0.16.1_x64.tar.gz
    chmod a+x goreplay
    ./goreplay --input-raw :80 --output-http="$GOREPLAY_HOST"&
else
    echo "Skipping GOREPLAY";
fi

# running the puma server
echo -e "\n\e[1m\e[44m Starting puma server..... \e[0m\n"
bin/bundle exec puma -C config/puma.rb;

echo -e "\n\e[1m\e[44m Starting cron..... \e[0m\n"
service cron start;

# config and start nginx
echo -e "\n\e[1m\e[44m Starting nginx..... \e[0m\n"
cp ./infra-config/nginx.conf /etc/nginx/nginx.conf
service nginx stop
nginx
