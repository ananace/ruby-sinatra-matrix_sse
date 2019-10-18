FROM ruby

COPY config.json.example Gemfile matrix_sse.gemspec /app/
COPY bin/ /app/bin/
COPY lib/ /app/lib/
WORKDIR /app

RUN bundle install -j4 \
 && echo "#!/bin/sh\ncd /app\nexec bundle exec bin/matrix_sse \"\$@\"" > /usr/local/bin/matrix_sse \
 && chmod +x /usr/local/bin/matrix_sse

ENTRYPOINT [ "/usr/local/bin/matrix_sse" ]
