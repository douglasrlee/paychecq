echo "Running database migrations..."
bundle exec rails db:migrate

echo "Setting deployment marker..."
curl -X POST https://api.newrelic.com/graphql \
  -H 'content-type: application/json; charset=utf-8' \
  -H 'API-Key: '$NEW_RELIC_API_KEY'' \
  --data-raw '{"query":"mutation { changeTrackingCreateDeployment(deployment: {version: \"'$HEROKU_RELEASE_VERSION'\", description: null, changelog: null, commit: \"'$HEROKU_SLUG_COMMIT'\", groupId: null, user: null, deploymentType: BASIC, entityGuid: \"'$NEW_RELIC_ENTITY_ID'\"}) { deploymentId description timestamp user } }","variables":{}}'
