defmodule EmbeddingService.RouterTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias EmbeddingService.Router

  @opts Router.init([])

  describe "GET /health" do
    test "returns ok status" do
      conn =
        :get
        |> conn("/health")
        |> Router.call(@opts)

      assert conn.status == 200
      assert %{"status" => "ok"} = Jason.decode!(conn.resp_body)
    end
  end

  describe "GET /v1/models" do
    test "returns list of available models" do
      conn =
        :get
        |> conn("/v1/models")
        |> Router.call(@opts)

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["object"] == "list"
      assert [%{"id" => "nomic-ai/nomic-embed-text-v1.5"}] = body["data"]
    end
  end

  describe "POST /v1/embeddings" do
    test "returns 400 when input is missing" do
      conn =
        :post
        |> conn("/v1/embeddings", Jason.encode!(%{}))
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 400
      assert %{"error" => %{"message" => "missing required field: input"}} =
               Jason.decode!(conn.resp_body)
    end

    test "returns 401 when token is required but missing" do
      Application.put_env(:embedding_service, :api_token, "test-secret")

      conn =
        :post
        |> conn("/v1/embeddings", Jason.encode!(%{input: "hello"}))
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 401

      Application.delete_env(:embedding_service, :api_token)
    end
  end

  describe "match _" do
    test "returns 404 for unknown routes" do
      conn =
        :get
        |> conn("/unknown")
        |> Router.call(@opts)

      assert conn.status == 404
    end
  end
end
