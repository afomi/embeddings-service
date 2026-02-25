defmodule EmbeddingService do
  @moduledoc """
  Standalone embedding inference service.

  Loads a Bumblebee text embedding model at boot and serves
  an OpenAI-compatible embeddings API over HTTP.
  """

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:embedding_service, :port, 8080)

    serving_children =
      if Application.get_env(:embedding_service, :start_serving, true) do
        [
          {Nx.Serving,
           serving: EmbeddingService.Serving.build_serving(),
           name: EmbeddingService.EmbeddingServing,
           batch_timeout: 100}
        ]
      else
        []
      end

    children =
      serving_children ++
        [
          {Bandit, plug: EmbeddingService.Router, port: port}
        ]

    opts = [strategy: :one_for_one, name: EmbeddingService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
