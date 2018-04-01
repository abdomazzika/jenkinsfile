#!/bin/bash

bundle check || bundle install
bundle exec rake db:create db:schema:load

# We don't want the container to exit to be able to run specs on in it on-demand
# with docker exec

tee
