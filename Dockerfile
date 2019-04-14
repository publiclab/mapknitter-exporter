# Dockerfile # Mapknitter
# https://github.com/publiclab/mapknitter/
# This image deploys Mapknitter!

FROM ruby:2.4.6-stretch

# Backported GDAL
RUN echo "deb http://packages.laboratoriopublico.org/publiclab/ stretch main" > /etc/apt/sources.list.d/publiclab.list

# Obtain key
RUN mkdir ~/.gnupg
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf
RUN apt-key adv --keyserver ipv4.pool.sks-keyservers.net --recv-keys BF26EE05EA6A68F0

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  gdal-bin curl procps git imagemagick python-gdal zip
RUN sed -i 's/<policy domain="delegate" rights="none" pattern="HTTPS" \/>//g' /etc/ImageMagick-6/policy.xml

# Add the Rails app
ADD . /app
WORKDIR /app

# Install bundle of gems
RUN bundle install


CMD ruby test/exporter_test.rb
