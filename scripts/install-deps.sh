#!/bin/bash

echo "deb http://packages.laboratoriopublico.org/publiclab/ stretch main" > /etc/apt/sources.list.d/publiclab.list

# Obtain key
mkdir -p ~/.gnupg
echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf
apt-key adv --keyserver ipv4.pool.sks-keyservers.net --recv-keys BF26EE05EA6A68F0
add-apt-repository -y ppa:ubuntugis/ppa

# Install dependencies
apt-get update -qq && apt-get install -y \
                        gdal-bin \
                        python3-gdal \
                        python-gdal \
                        libgdal-dev \
                        g++ \
                        curl \
                        procps \
                        git \
                        imagemagick \
                        zip

sed -i 's/<policy domain="delegate" rights="none" pattern="HTTPS" \/>//g' /etc/ImageMagick-6/policy.xml
