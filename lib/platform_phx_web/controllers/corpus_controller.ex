defmodule PlatformPhxWeb.CorpusController do
  use PlatformPhxWeb, :controller

  @moduledoc false

  def learn(conn, %{"path" => path}), do: send_corpus_page(conn, "learn", path)
  def glossary(conn, %{"path" => path}), do: send_corpus_page(conn, "glossary", path)
  def source(conn, %{"path" => path}), do: send_corpus_page(conn, "source", path)
  def updates(conn, %{"path" => path}), do: send_corpus_page(conn, "updates", path)

  defp send_corpus_page(conn, section, path) when is_list(path) do
    static_root = :code.priv_dir(:platform_phx) |> Path.join("static")

    requested_path =
      [section | path]
      |> Kernel.++(["index.html"])
      |> Path.join()

    file_path = Path.expand(requested_path, static_root)

    if String.starts_with?(file_path, Path.expand(static_root) <> "/") and
         File.regular?(file_path) do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, file_path)
    else
      send_resp(conn, 404, "Not Found")
    end
  end
end
