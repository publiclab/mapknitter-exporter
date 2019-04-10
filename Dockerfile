# Dockerfile # Mapknitter
# https://github.com/publiclab/mapknitter/
# This image deploys Mapknitter!

FROM ruby:2.4.6-stretch

# Backported GDAL
RUN echo "deb http://packages.laboratoriopublico.org/publiclab/ stretch main" > /etc/apt/sources.list.d/publiclab.list

# Obtain key
RUN mkdir ~/.gnupg
RUN echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf
RUN apt-key adv --keyserver hkps.pool.sks-keyservers.net --recv-keys BF26EE05EA6A68F0

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  gdal-bin curl procps git imagemagick python-gdal zip

# Install bundle of gems
WORKDIR /tmp
ADD Gemfile /tmp/Gemfile
ADD Gemfile.lock /tmp/Gemfile.lock
RUN bundle install

# Add the Rails app
ADD . /app
WORKDIR /app
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock

CMD ruby test/exporter_test.rb
