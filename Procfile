web: bin/rails server
worker: bin/rails solid_queue:start
release: bundle exec rails db:migrate && bundle exec newrelic_rpm deployment --appid=$NEW_RELIC_APP_ID --revision=$HEROKU_BUILD_COMMIT $HEROKU_BUILD_DESCRIPTION
