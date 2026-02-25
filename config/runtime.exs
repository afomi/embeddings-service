import Config

if port = System.get_env("PORT") do
  config :embedding_service, :port, String.to_integer(port)
end

if model = System.get_env("EMBEDDING_MODEL") do
  config :embedding_service, :model, model
end

if token = System.get_env("EMBEDDING_API_TOKEN") do
  config :embedding_service, :api_token, token
end
