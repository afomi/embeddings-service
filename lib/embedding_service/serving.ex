defmodule EmbeddingService.Serving do
  @moduledoc """
  Builds an Nx.Serving for the configured embedding model using Bumblebee.
  """

  @doc """
  Builds and returns an Nx.Serving configured with the embedding model.

  The model is determined by the `EMBEDDING_MODEL` env var,
  defaulting to `nomic-ai/nomic-embed-text-v1.5`.
  """
  def build_serving do
    model_name = Application.get_env(:embedding_service, :model, "nomic-ai/nomic-embed-text-v1.5")

    {:ok, model_info} =
      Bumblebee.load_model({:hf, model_name},
        module: Bumblebee.Text.Bert,
        backend: EXLA.Backend
      )

    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, model_name}, type: :bert)

    Bumblebee.Text.text_embedding(model_info, tokenizer,
      output_pool: :mean_pooling,
      output_attribute: :hidden_state,
      embedding_processor: :l2_norm,
      compile: [batch_size: 8, sequence_length: 512],
      defn_options: [compiler: EXLA]
    )
  end
end
