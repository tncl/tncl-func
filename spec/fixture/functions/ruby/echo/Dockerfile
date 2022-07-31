FROM ruby:3.1-alpine

RUN apk add --no-cache curl git make \
    libssl1.1 build-base libxml2-dev libxslt-dev libbz2 libevent-dev libffi-dev \
    glib-dev ncurses-dev readline-dev yaml-dev zlib-dev \
    libpq sqlite-dev postgresql-dev

RUN gem update bundler

WORKDIR /function

RUN bundle config set --local without 'development test'
RUN bundle config set --local with 'production'

COPY Gemfile Gemfile.lock ./

RUN bundle install

ADD . ./

CMD exec ruby main.rb
