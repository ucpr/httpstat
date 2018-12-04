FROM nimlang/nim

MAINTAINER Taichi Uchihara <hoge.uchihara@gmail.com>

RUN \
  apt-get update -y && apt-get install curl -y | exit 0 && git clone https://github.com/nve3pd/httpstat ./httpstat && cd ./httpstat && nimble install -y 

ENTRYPOINT ["httpstat"]
