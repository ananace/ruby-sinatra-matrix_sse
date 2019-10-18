FROM ruby

COPY config.json.example Gemfile matrix_sse.gemspec /app/
COPY bin/ /app/bin/
COPY lib/ /app/lib/
WORKDIR /app

RUN bundle install -j4 --binstubs=/usr/local/bin

ENTRYPOINT /usr/local/bin/matrix_sse
