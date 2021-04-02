FROM ruby:2.7.2
COPY module/ /var/task/
WORKDIR /var/task/qiiteneeyo
RUN rm -rf vendor/bundle
RUN bundle install --path=vendor/bundle
ENTRYPOINT [ "/bin/bash" ]

# Redefine below when upload to AWS Lambda
# WORKDIR /var/task
# ENTRYPOINT [ "/var/task/bootstrap" ]
# CMD [ "lambda_function.lambda_handler" ]
