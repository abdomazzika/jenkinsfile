#!/bin/bash
set -x

echo -e "\e[1m\nRunning dependency containers\e[0m\n"
docker rm -f $(docker ps -a -q)
docker network create -d bridge isolated_nw | cat
docker run -d --network isolated_nw --name=redis redis
docker run -d --network isolated_nw --name=database -e 'MYSQL_ROOT_PASSWORD=root' 'mysql:5.6'
docker run -d --network isolated_nw --name=elasticsearch instabug/test-elasticsearch:latest
docker run -d --network isolated_nw --name=elasticsearch-sessions instabug/test-elasticsearch:latest --http.port=9201
docker run -d --network isolated_nw --name=elasticsearch-oom-sessions instabug/test-elasticsearch:latest --http.port=9202
docker run -d --network isolated_nw --name=zookeeper library/zookeeper
docker run -d --network isolated_nw --name=kafka confluent/kafka

function setupBundle {
  echo -e "\e[1m\n Setting-up bundle\n\e[0m"
  serviceName=$2
  sudo rm -rf /bundle_$serviceName
  sudo mkdir -p /bundle_$serviceName/bundle
  sudo chown -R $(whoami):$(whoami) /bundle_$serviceName
  sudo mkdir -p /report_$serviceName
  sudo chown -R $(whoami):$(whoami) /report_$serviceName

  # calculate bundle ID by hashing the concatenation of Gemfile + Gemfile.lock + `ruby -v`
  imageName=$1
  echo $imageName
  docker pull $imageName
  string=$(docker run --rm $imageName bash -c "cat Gemfile* && ruby -v")
  bundleHash=$(echo $string | sha256sum | sed 's/ /_/g' | xargs -I {} echo {}'.tar.gz')
  echo "#####################"
  echo $string
  echo $bundleHash > bundleHash
  # check if a bundle with that hash is available
  wget http://public-bundles.s3.amazonaws.com/$bundleHash && tar xf $bundleHash -C /bundle_$serviceName/
  if [ "$?" != "0" ]; then
      echo -e "\e[33mCouldn't find a bundle with that hash, will \e[1;33m'bundle install' \e[0;33mfrom scratch...\e[0m"
      rm -rf /bundle_$serviceName
      mkdir -p /bundle_$serviceName/bundle
      docker run --rm -v /bundle_$serviceName/bundle:/bundle $imageName bash -c "bundle install && bundle clean"
      sudo chown -R $(whoami):$(whoami) /bundle_$serviceName
      tar -C /bundle_$serviceName -cf $bundleHash bundle
  fi
}

setupBundle $1 $2
