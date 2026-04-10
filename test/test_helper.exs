ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Web.Repo, :manual)
Application.put_env(:web, :ethereum_adapter, Web.TestEthereumAdapter)
