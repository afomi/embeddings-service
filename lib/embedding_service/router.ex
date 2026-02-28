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

  get "/demo" do
    token = Application.get_env(:embedding_service, :api_token, "")
    send_html(conn, demo_page(token))
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

  defp send_html(conn, body) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, body)
  end

  defp demo_page(api_token) do
    ~s"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>Embedding Service Demo</title>
      <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: system-ui, -apple-system, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; color: #1b1b1b; }
        h1 { margin-bottom: 0.5rem; }
        p.subtitle { color: #71767a; margin-bottom: 1.5rem; }
        label { display: block; font-weight: 600; margin-bottom: 0.25rem; }
        textarea { width: 100%; padding: 0.5rem; font-size: 1rem; font-family: inherit; border: 1px solid #c9c9c9; border-radius: 4px; resize: vertical; }
        button { margin-top: 0.75rem; padding: 0.625rem 1.25rem; font-size: 1rem; font-weight: 600; color: #fff; background: #005ea2; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #1a4480; }
        button:disabled { background: #c9c9c9; cursor: not-allowed; }
        #result { margin-top: 1.5rem; }
        pre { background: #f0f0f0; padding: 1rem; border-radius: 4px; overflow-x: auto; font-size: 0.875rem; line-height: 1.5; white-space: pre-wrap; word-break: break-all; }
        .error { color: #b50909; }
        .meta { color: #71767a; font-size: 0.875rem; margin-top: 0.5rem; }
      </style>
    </head>
    <body>
      <h1>Embedding Service</h1>
      <p class="subtitle">Generate text embeddings using nomic-embed-text-v1.5</p>
      <form id="embed-form">
        <label for="input-text">Text to embed</label>
        <textarea
          id="input-text"
          name="input"
          rows="4"
          placeholder="Enter text to generate an embedding..."
          required
        ></textarea>
        <button type="submit" id="submit-btn">Generate Embedding</button>
      </form>
      <div id="result"></div>
      <script>
        const form = document.getElementById('embed-form');
        const btn = document.getElementById('submit-btn');
        const result = document.getElementById('result');

        form.addEventListener('submit', async (e) => {
          e.preventDefault();
          const text = document.getElementById('input-text').value.trim();
          if (!text) return;

          btn.disabled = true;
          btn.textContent = 'Generating...';
          result.innerHTML = '';

          const start = performance.now();

          try {
            const headers = { 'Content-Type': 'application/json' };
            const token = '#{api_token}';
            if (token) headers['Authorization'] = 'Bearer ' + token;

            const resp = await fetch('/v1/embeddings', {
              method: 'POST',
              headers: headers,
              body: JSON.stringify({
                input: text,
                model: 'nomic-ai/nomic-embed-text-v1.5',
                task_prefix: 'search_document'
              })
            });

            const data = await resp.json();
            const elapsed = ((performance.now() - start) / 1000).toFixed(2);

            if (!resp.ok) {
              result.innerHTML = '<p class="error">Error: ' + (data.error?.message || resp.statusText) + '</p>';
              return;
            }

            const dims = data.data?.[0]?.embedding?.length || 0;
            result.innerHTML =
              '<p class="meta">' + dims + ' dimensions &middot; ' + elapsed + 's</p>' +
              '<pre><code>' + escapeHtml(JSON.stringify(data, null, 2)) + '</code></pre>';
          } catch (err) {
            result.innerHTML = '<p class="error">Request failed: ' + escapeHtml(err.message) + '</p>';
          } finally {
            btn.disabled = false;
            btn.textContent = 'Generate Embedding';
          }
        });

        function escapeHtml(str) {
          return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
        }
      </script>
    </body>
    </html>
    """
  end
end
