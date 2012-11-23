    bundle install --path vendor/bundle
    bundle exec thin start -p 3000 -e production
