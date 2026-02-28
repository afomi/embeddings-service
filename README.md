# Embedding Service

A standalone Elixir service that runs text embedding inference via Bumblebee and serves an OpenAI-compatible API.

## API

### `POST /v1/embeddings`

OpenAI-compatible endpoint.
Accepts single or batch input.

```json
{
  "input": "some text to embed",
  "model": "nomic-ai/nomic-embed-text-v1.5",
  "task_prefix": "search_document"
}
```

The `task_prefix` field is an optional extension for Nomic models (`search_document` or `search_query`).

### `GET /v1/models`

Lists available models.

### `GET /health`

Liveness check.
Returns `{"status": "ok"}`.

## Authentication

Requests require a bearer token when `EMBEDDING_API_TOKEN` is set.

```
Authorization: Bearer <token>
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP listen port |
| `EMBEDDING_MODEL` | `nomic-ai/nomic-embed-text-v1.5` | HuggingFace model to load at boot |
| `EMBEDDING_API_TOKEN` | _(none)_ | Bearer token for authentication (disabled when unset) |

## Local Development

```bash
mix deps.get
mix run --no-halt
```

Test the API:

```bash
curl -X POST http://localhost:8080/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello world", "model": "nomic-ai/nomic-embed-text-v1.5"}'
```

Run tests:

```bash
mix test
```

## Deploy to Fly.io

### First deploy

```bash
fly launch
```

### Generate and set the API token

```bash
openssl rand -hex 32
```

Set it on the embedding service:

```bash
fly secrets set EMBEDDING_API_TOKEN=<token> -a your-fly-app-name
```


### Subsequent deploys

```bash
fly deploy
```

### Test the deployed service

```bash
curl -X POST https://your-fly-app-name.fly.dev/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $EMBEDDING_API_TOKEN" \
  -d '{"input": "How satisfied are you with this service?", "model": "nomic-ai/nomic-embed-text-v1.5", "task_prefix": "search_document"}'
```

Health check:

```bash
curl https://your-fly-app-name.fly.dev/health
```
