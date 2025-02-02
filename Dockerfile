FROM crystallang/crystal:0.31.1

RUN apt-get update \
  && apt-get install -y libnss3 libgconf-2-4 chromium-browser

RUN mkdir /data
WORKDIR /data
ADD . /data
EXPOSE 3002
