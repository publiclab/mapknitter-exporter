#!/bin/bash

echo "deb [trusted=yes] http://packages.laboratoriopublico.org/publiclab/ stretch main" > /etc/apt/sources.list.d/publiclab.list

# Add repository 
add-apt-repository -y ppa:ubuntugis/ppa

# Install dependencies
apt-get update -qq && apt-get install --allow-unauthenticated -y \
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
