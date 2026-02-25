import Config

# Don't load the embedding model in tests
config :embedding_service, :start_serving, false

config :logger, level: :warning
