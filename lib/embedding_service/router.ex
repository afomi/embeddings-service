defmodule EmbeddingService.Router do
  @moduledoc """
  Plug router implementing an OpenAI-compatible embeddings API.

  Endpoints:
  - POST /v1/embeddings — generate embeddings for input text(s)
  - GET  /v1/models     — list available models
  - GET  /health        — liveness check
  """

  use Plug.Router

  plug Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason

  plug :match
  plug :dispatch

  get "/health" do
    send_json(conn, 200, %{status: "ok"})
  end

  get "/v1/models" do
    model = Application.get_env(:embedding_service, :model, "nomic-ai/nomic-embed-text-v1.5")

    send_json(conn, 200, %{
      object: "list",
      data: [
        %{
          id: model,
          object: "model",
          owned_by: "local"
        }
      ]
    })
  end

  post "/v1/embeddings" do
    with :ok <- check_auth(conn),
         {:ok, inputs, task_prefix} <- parse_request(conn.body_params) do
      model = Application.get_env(:embedding_service, :model, "nomic-ai/nomic-embed-text-v1.5")

      data =
        inputs
        |> Enum.with_index()
        |> Enum.map(fn {text, index} ->
          prefixed =
            if task_prefix do
              "#{task_prefix}: #{text}"
            else
              text
            end

          %{embedding: embedding} =
            Nx.Serving.batched_run(EmbeddingService.EmbeddingServing, prefixed)

          vector = Nx.to_flat_list(embedding)

          %{
            object: "embedding",
            index: index,
            embedding: vector
          }
        end)

      total_tokens = inputs |> Enum.join(" ") |> String.split() |> length()

      send_json(conn, 200, %{
        object: "list",
        data: data,
        model: model,
        usage: %{
          prompt_tokens: total_tokens,
          total_tokens: total_tokens
        }
      })
    else
      {:error, status, message} ->
        send_json(conn, status, %{error: %{message: message, type: "invalid_request_error"}})
    end
  end

  match _ do
    send_json(conn, 404, %{error: %{message: "not found", type: "invalid_request_error"}})
  end

  defp check_auth(conn) do
    expected_token = Application.get_env(:embedding_service, :api_token)

    if is_nil(expected_token) or expected_token == "" do
      :ok
    else
      case Plug.Conn.get_req_header(conn, "authorization") do
        ["Bearer " <> token] when token == expected_token -> :ok
        _ -> {:error, 401, "invalid or missing authorization token"}
      end
    end
  end

  defp parse_request(%{"input" => input} = params) when is_binary(input) do
    {:ok, [input], Map.get(params, "task_prefix")}
  end

  defp parse_request(%{"input" => inputs} = params) when is_list(inputs) do
    if Enum.all?(inputs, &is_binary/1) do
      {:ok, inputs, Map.get(params, "task_prefix")}
    else
      {:error, 400, "all inputs must be strings"}
    end
  end

  defp parse_request(_) do
    {:error, 400, "missing required field: input"}
  end

  defp send_json(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Jason.encode!(body))
  end
end
