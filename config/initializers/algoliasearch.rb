# Algolia is only configured when the write API key is present. The app ID
# is public-safe (ships in any client-side call) so it's hardcoded with an
# env override. Without the key, Session.algolia_enabled? returns false and
# the search UI toggle falls back to FTS5.
#
#   export ALGOLIA_WRITE_API_KEY=...
#   export ALGOLIA_APP_ID=...   # optional

if ENV["ALGOLIA_WRITE_API_KEY"].present?
  AlgoliaSearch.configuration = {
    application_id: ENV.fetch("ALGOLIA_APP_ID", "R9QVL1PO4I"),
    api_key: ENV["ALGOLIA_WRITE_API_KEY"]
  }
end
