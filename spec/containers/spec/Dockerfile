FROM crystallang/crystal:latest

RUN apt-get update \
    && apt-get install -y libmongoc-dev libmongoc-1.0-0 libmongoclient-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

WORKDIR /code
