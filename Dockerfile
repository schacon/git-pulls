FROM ruby:2

RUN gem install git-pulls

VOLUME /app

VOLUME /root/.gitconfig

WORKDIR /app

ENTRYPOINT ["git","pulls"]
