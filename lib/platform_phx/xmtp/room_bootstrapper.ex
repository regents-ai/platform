defmodule PlatformPhx.Xmtp.RoomBootstrapper do
  @moduledoc false

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def sync_now(timeout) do
    GenServer.call(__MODULE__, :sync_now, timeout)
  end

  @impl true
  def init(opts) do
    state = %{
      interval_ms: Keyword.fetch!(opts, :interval_ms),
      auto_sync?: Keyword.fetch!(opts, :auto_sync?)
    }

    if state.auto_sync? do
      send(self(), :sync_rooms)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:sync_now, _from, state) do
    {:reply, PlatformPhx.Xmtp.bootstrap_current_rooms(), state}
  end

  @impl true
  def handle_info(:sync_rooms, state) do
    _result = safe_sync_rooms()
    Process.send_after(self(), :sync_rooms, state.interval_ms)
    {:noreply, state}
  end

  defp safe_sync_rooms do
    PlatformPhx.Xmtp.bootstrap_current_rooms()
  rescue
    _error -> :error
  catch
    _kind, _reason -> :error
  end
end
