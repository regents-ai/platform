defmodule PlatformPhx.AgentLaunch do
  @moduledoc false

  import Ecto.Query, warn: false

  alias PlatformPhx.AgentLaunch.Auction
  alias PlatformPhx.Repo

  @type auction :: map()
  @type auction_payload :: %{
          required(:auctions) => [map()],
          required(:generated_at) => DateTime.t()
        }
  @type auction_split :: %{required(:current) => [map()], required(:past) => [map()]}

  @spec list_auctions() :: [auction()]
  def list_auctions do
    Repo.all(from auction in Auction, order_by: [asc: auction.ends_at])
    |> Enum.map(&normalize_auction/1)
  end

  @spec split_auctions([auction()]) :: auction_split()
  def split_auctions(auctions) do
    now = DateTime.utc_now()

    Enum.reduce(auctions, %{current: [], past: []}, fn auction, acc ->
      past? =
        auction.status == "settled" or
          (match?(%DateTime{}, auction.ends_at) and DateTime.compare(auction.ends_at, now) != :gt)

      if past? do
        %{acc | past: [auction | acc.past]}
      else
        %{acc | current: [auction | acc.current]}
      end
    end)
    |> then(fn %{current: current, past: past} ->
      %{
        current: Enum.sort_by(current, & &1.ends_at, DateTime),
        past: Enum.sort_by(past, & &1.ends_at, {:desc, DateTime})
      }
    end)
  end

  @spec generated_payload() :: auction_payload()
  def generated_payload do
    list_auctions()
    |> generated_payload()
  end

  @spec generated_payload([auction()]) :: auction_payload()
  def generated_payload(auctions) do
    %{
      auctions: Enum.map(auctions, &public_auction/1),
      generated_at: DateTime.utc_now()
    }
  end

  @spec public_auction(auction()) :: map()
  def public_auction(auction) do
    %{
      id: auction.id,
      agent_id: auction.agent_id,
      agent_name: auction.agent_name,
      owner_address: auction.owner_address,
      auction_address: auction.auction_address,
      token_address: auction.token_address,
      network: auction.network,
      status: auction.status,
      started_at: iso_or_nil(auction.started_at),
      ends_at: iso_or_nil(auction.ends_at),
      claim_at: iso_or_nil(auction.claim_at),
      bidders: auction.bidders,
      raised_currency: auction.raised_currency,
      target_currency: auction.target_currency,
      progress_percent: auction.progress_percent,
      notes: auction.notes,
      uniswap_url: auction.uniswap_url
    }
  end

  defp normalize_auction(%Auction{} = auction), do: auction

  defp iso_or_nil(nil), do: nil
  defp iso_or_nil(%DateTime{} = value), do: DateTime.to_iso8601(value)
end
