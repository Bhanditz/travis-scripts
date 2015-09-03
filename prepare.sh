#!/bin/bash
if [ "$SKIP_PIWIK_TEST_PREPARE" == "1" ]; then
    echo "Skipping Piwik specific test peparation."
    exit 0;
fi

set -e

sudo apt-get update > /dev/null

# Install XMLStarlet
sudo apt-get install -qq xmlstarlet > /dev/null

# Install fonts for UI tests
if [ "$TEST_SUITE" = "UITests" ];
then
    sudo cp ./tests/travis/fonts/* /usr/share/fonts/
fi

# Copy Piwik configuration
echo "Install config.ini.php"
sed "s/PDO\\\MYSQL/${MYSQL_ADAPTER}/g" ./tests/PHPUnit/config.ini.travis.php > ./config/config.ini.php

# Prepare phpunit.xml
echo "Adjusting phpunit.xml"
cp ./tests/PHPUnit/phpunit.xml.dist ./tests/PHPUnit/phpunit.xml

if grep "@REQUEST_URI@" ./tests/PHPUnit/phpunit.xml > /dev/null; then
    sed -i 's/@REQUEST_URI@/\//g' ./tests/PHPUnit/phpunit.xml
fi

if [ -n "$PLUGIN_NAME" ];
then
      sed -n '/<filter>/{p;:a;N;/<\/filter>/!ba;s/.*\n/<whitelist addUncoveredFilesFromWhitelist=\"true\">\n<directory suffix=\".php\">..\/..\/plugins\/'$PLUGIN_NAME'<\/directory>\n<exclude>\n<directory suffix=\".php\">..\/..\/plugins\/'$PLUGIN_NAME'\/tests<\/directory>\n<directory suffix=\".php\">..\/..\/plugins\/'$PLUGIN_NAME'\/Test<\/directory>\n<directory suffix=\".php\">..\/..\/plugins\/'$PLUGIN_NAME'\/Updates<\/directory>\n<\/exclude>\n<\/whitelist>\n/};p' ./tests/PHPUnit/phpunit.xml > ./tests/PHPUnit/phpunit.xml.new && mv ./tests/PHPUnit/phpunit.xml.new ./tests/PHPUnit/phpunit.xml
fi;

# If we have a test suite remove code coverage report
if [ -n "$TEST_SUITE" ]
then
	xmlstarlet ed -L -d "//phpunit/logging/log[@type='coverage-html']" ./tests/PHPUnit/phpunit.xml
fi

# Create tmp/ sub-directories
mkdir -p ./tmp/assets
mkdir -p ./tmp/cache
mkdir -p ./tmp/latest
mkdir -p ./tmp/logs
mkdir -p ./tmp/sessions
mkdir -p ./tmp/templates_c
mkdir -p ./tmp/tcpdf
mkdir -p ./tmp/climulti
chmod a+rw ./tests/lib/geoip-files || true
chmod a+rw ./plugins/*/tests/System/processed || true
chmod a+rw ./plugins/*/tests/Integration/processed || true

# install phpredis
if [[ "$TRAVIS_PHP_VERSION" == 7* ]];
then
    # travis does not support redis for PHP 7 yet, in https://github.com/phpredis/phpredis/issues/652 it is recommended to use
    # https://github.com/Sean-Der/phpredis/tree/php7 for now, should maybe later change it to https://github.com/phpredis/phpredis
    # or use redis provided by travis as soon as possible
    echo "extension=redis.so" >> ~/.phpenv/versions/$(phpenv version-name)/etc/php.ini
    git clone --branch=php7 https://github.com/edtechd/phpredis phpredis;
    cd phpredis
    phpize
    ./configure
    make
    sudo make install
    cd ..
    rm -fr phpredis
else
    echo 'extension="redis.so"' > ./tmp/redis.ini
    phpenv config-add ./tmp/redis.ini
fi;
