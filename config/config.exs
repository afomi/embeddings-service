import Config

config :embedding_service,
  port: 8080,
  model: "nomic-ai/nomic-embed-text-v1.5"

config :nx, default_backend: EXLA.Backend

import_config "#{config_env()}.exs"
