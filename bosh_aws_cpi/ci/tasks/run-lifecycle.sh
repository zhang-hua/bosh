#!/usr/bin/env bash

set -e -x

export BOSH_CLI_SILENCE_SLOW_LOAD_WARNING=true

source bosh-deployments/concourse/$cpi_release_name/lifecycle-exports.sh

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

cd bosh-src

if [ -f .bundle/config ]; then
  echo ".bundle/config:"
  cat .bundle/config
fi

bundle install

cd $cpi_directory
bundle exec rake spec:lifecycle
