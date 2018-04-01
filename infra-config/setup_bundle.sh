#!/bin/bash

mkdir -p /bundle
string=$(cat Gemfile* && ruby -v)
bundleHash=$(echo $string | sha256sum | sed 's/ /_/g' | xargs -I {} echo {}'.tar.gz')

gem install bundler

# check if a bundle with that hash is available
wget http://public-bundles.s3.amazonaws.com/$bundleHash && tar xf $bundleHash -C / | cat
if [ $? != "0" ]; then
  echo -e "\e[33mCouldn't find a bundle with that hash, will \e[1;33m'bundle install' \e[0;33mfrom scratch...\e[0m"
  bundle install && bundle clean
fi

rm $bundleHash | cat # remove bundle zip file to reduce image size
