#!/usr/bin/env bash

if ! [ -e /home/site/wwwroot/Gemfile ] && [ -z "$RAILS_IGNORE_SPLASH" ]
  then
   echo 'No Gemfile found and RAILS_IGNORE_SPLASH not set, running default static site'
   exec ruby /opt/staticsite.rb
fi

if [ -z "$BUNDLE_WITHOUT" ]; then 
  echo "Bundle install with no 'without' options"; 
  RUBY_OPTIONS="";
else 
  RUBY_OPTIONS="--without $BUNDLE_WITHOUT";
  echo "Bundle install with options $RUBY_OPTIONS";
fi

if [ -z "$BUNDLE_INSTALL_LOCATION" ]; then 
  echo "Defaulting gem installation directory to /tmp/bundle"; 
  BUNDLE_INSTALL_LOCATION="/tmp/bundle";
else 
  echo "Gem installation directory is $BUNDLE_INSTALL_LOCATION";
fi

if [ -z "$RUBY_SITE_CONFIG_DIR" ]; then 
  echo "Defaulting site config directory to /home/site/config"; 
  RUBY_SITE_CONFIG_DIR="/home/site/config"
else 
  echo "site config directory is $RUBY_SITE_CONFIG_DIR";
fi

if [ -n "$SECRET_KEY_BASE" ]
  then
    echo 'Secret key base present'
  else
    echo 'Generating a secret key base'
    export SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')
fi

if [ -n "$RAILS_ENV" ]
  then
    echo "RAILS_ENV set to $RAILS_ENV"
  else
    echo 'RAILS_ENV not set, default to production'
    export RAILS_ENV='production'
fi

echo 'Removing any leftover pids if present'
rm -f tmp/pids/* ;

# Support zipped gems 
export ZIPPED_GEMS=0
if [ -f  "${RUBY_SITE_CONFIG_DIR}/gems.tgz" ]
  then
    echo "gems.tgz detected, beginning unzipping process"
    echo "unzipping..."
    mkdir -p $BUNDLE_INSTALL_LOCATION
    cp  ${RUBY_SITE_CONFIG_DIR}/gems.tgz /tmp
    tar -C $BUNDLE_INSTALL_LOCATION -xf /tmp/gems.tgz
    
    echo 'Removing bundler config'
    rm -f ${BUNDLE_INSTALL_LOCATION}/config
    
    export ZIPPED_GEMS=1
fi

export CHECK_PASSED=0
echo 'Running bundle check'
if [ "$ZIPPED_GEMS" -eq 1 ]
  then
    bundle config --global path $BUNDLE_INSTALL_LOCATION
    if bundle check | grep satisfied
      then
        echo 'dependency check passed'
        export CHECK_PASSED=1
      else
        echo 'missing dependencies, try redeploying'
        echo `bundle check`
    fi
  else
    bundle config --local path "vendor/bundle"
    if bundle check --path "vendor/bundle" | grep satisfied
      then
        echo 'dependency check passed'
        export CHECK_PASSED=1
      else
        echo 'missing dependencies, try redeploying'
        echo `bundle check --path "vendor/bundle"`
    fi
fi

if [ "$CHECK_PASSED" -eq 0 ]
  then
    if [ "$ZIPPED_GEMS" -eq 1 ]
      then
        echo "running bundle install $RUBY_OPTIONS --no-deployment"
        bundle install --no-deployment $RUBY_OPTIONS
      else
        echo "running bundle install $RUBY_OPTIONS --local --path vendor/bundle"
        bundle install  $RUBY_OPTIONS --local --path vendor/bundle
    fi
fi

if [ -n "$GEM_PRISTINE" ]
  then
    echo 'running "gem pristine --all"'
    bundle exec gem pristine --all
fi

if [ $# -ne 0 ]
  then
    echo "Executing custom startup: $@"
    echo "$@" > /opt/startup/startupCommand
    STARTUPCOMMAND=$(cat /opt/startup/startupCommand)
    echo "Running $STARTUPCOMMAND"
    eval "$STARTUPCOMMAND"
fi

echo "defaulting to command: \"bundle exec rails server -e $RAILS_ENV -p $PORT\""
bundle exec rails server -b 0.0.0.0 -e "$RAILS_ENV" -p "$PORT"
