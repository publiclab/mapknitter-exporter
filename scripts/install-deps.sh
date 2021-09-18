#!/bin/bash

echo "deb [trusted=yes] http://packages.laboratoriopublico.org/publiclab/ stretch main" > /etc/apt/sources.list.d/publiclab.list

# Obtain key
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
