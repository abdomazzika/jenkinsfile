FROM hungerstation/base-rails:ruby-2.1.9-enhanced

MAINTAINER Abdelrahman Mohamed "abdullrahmanmuhamed@gmail.com"

ENV app /var/app
RUN mkdir -p $app/log
WORKDIR $app
ENV BUNDLE_GEMFILE=$app/Gemfile
ENV BUNDLE_JOBS=4
ENV BUNDLE_PATH=/bundle
COPY . .
RUN ./infra-config/setup_bundle.sh
CMD ["./infra-config/default_entry_point.sh"]
