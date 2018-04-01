#!/bin/bash

# sync new migrations
echo -e "\n\e[1m\e[44m Migrating database..... \e[0m\n"
bin/rake db:migrate;
bin/rake assets:precompile;

# Update crontab
env | xargs -n 1 echo "export " >> $HOME/.profile;
bin/bundle exec whenever --set "environment=$RACK_ENV" --update-crontab
service cron start

# running the puma server
echo -e "\n\e[1m\e[44m Starting puma server..... \e[0m\n"
bin/bundle exec puma -C config/puma.rb;

# config and start nginx
echo -e "\n\e[1m\e[44m Starting nginx..... \e[0m\n"
cp ./infra-config/nginx.conf /etc/nginx/nginx.conf
service nginx stop
nginx
