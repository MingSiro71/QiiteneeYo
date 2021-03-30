FROM ruby:2.7.2
COPY module/ /var/task/
WORKDIR /var/task/qiiteneeyo
RUN rm -rf vendor/bundle
RUN bundle install --path=vendor/bundle
ENTRYPOINT [ "/bin/bash" ]

# Redefine below when upload to AWS Lambda
# WORKDIR /var/task
# ENTRYPOINT [ "/usr/local/bin/ruby" ]
# CMD [ "/var/task/lambda_function.rb" ]