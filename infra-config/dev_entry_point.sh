#!/bin/bash

echo -e "\n\e[1m\e[44m Installing gems..... \e[0m\n"
bundle install

echo -e "\n\e[1m\e[44m Trying to migrate database..... \e[0m\n"
bin/rake db:migrate 2>/dev/null
if [ "$?" != "0" ]; then
  echo -e "\n\e[1m\e[44m Migration failed, creating database first..... \e[0m\n"
  bin/rake db:create db:schema:load db:seed db:migrate
  echo -e "\n\e[1m\e[44m Indexing elasticsearch..... \e[0m\n"
  bin/rake elasticsearch:create_indexes
  bin/rake elasticsearch:index_all
  bin/rails runner "Application.all.map &:create_example_data"
fi

echo -e "\n\e[1m\e[44m Running container's command..... \e[0m\n"
rm -rf /var/app/tmp/pids/server.pid
bundle exec rails s -p 3000 -b 0.0.0.0
