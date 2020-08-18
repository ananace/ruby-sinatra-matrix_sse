FROM ruby

ENV APP_HOME /app
ENV RACK_ENV production
RUN mkdir $APP_HOME
WORKDIR /app

ADD Gemfile* $APP_HOME/
ADD *gemspec $APP_HOME/
ADD config.json.example config.ru $APP_HOME/
ADD lib $APP_HOME/lib/

RUN bundle install -j4 --without development

EXPOSE 9292/tcp
CMD ["bundle", "exec", "rackup"]
