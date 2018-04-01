#!/bin/bash
set -x

if [ "$RAILS_ENV" == "production" ]; then
    ./infra-config/prod_entry_point.sh
elif [ "$RAILS_ENV" == "staging" ]; then
    ./infra-config/staging_entry_point.sh
elif [ "$RAILS_ENV" == "kaching" ]; then
    ./infra-config/staging_entry_point.sh
elif [ "$RAILS_ENV" == "development" ]; then
    ./infra-config/dev_entry_point.sh
else
  ./infra-config/test_entry_point.sh
fi
