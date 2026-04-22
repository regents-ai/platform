defmodule PlatformPhx.TokenInfoContent do
  @moduledoc false

  @holders [
    %{
      rank: 1,
      label: "Clanker Vault",
      address: "0x8E845EAd15737bF71904A30BdDD3aEE76d6ADF6C",
      short: "0x8E84...DF6C",
      percent: "40.00%",
      amount: "40.0B",
      description:
        "Clanker Vault. This is the long-term locked vault attached to the Clanker deployment and vesting schedule.",
      link_label: "View on Clanker",
      link_url: "https://clanker.world/clanker/0x6f89bcA4eA5931EdFCB09786267b251DeE752b07"
    },
    %{
      rank: 2,
      label: "Regent Multisig",
      address: "0x9fa152B0EAdbFe9A7c5C0a8e1D11784f22669a3e",
      short: "0x9fa1...9a3e",
      percent: "36.52%",
      amount: "36.5B",
      description:
        "Regent Multisig. This is the main team-controlled Safe that receives and manages the Regent Labs allocation buckets.",
      link_label: "View Safe",
      link_url:
        "https://app.safe.global/balances?safe=base:0x9fa152B0EAdbFe9A7c5C0a8e1D11784f22669a3e"
    },
    %{
      rank: 3,
      label: "Uniswap V4 Pool Liquidity",
      address: "0x498581fF718922c3f8e6A244956aF099B2652b2b",
      short: "0x4985...2b2b",
      percent: "8.26%",
      amount: "8.2B",
      description:
        "Uniswap V4 Pool Liquidity. This address is the pool manager position holding the liquidity allocated to the market.",
      link_label: "View on BaseScan",
      link_url: "https://basescan.org/address/0x498581ff718922c3f8e6a244956af099b2652b2b"
    },
    %{
      rank: 4,
      label: "Animata Redeem Contract",
      address: "0x71065b775a590c43933F10c0055dc7d74AfAbb0e",
      short: "0x7106...bb0e",
      percent: "2.98%",
      amount: "2.9B",
      description:
        "Animata Redeem Contract with roughly 3B still remaining to disburse. This is the locked onchain pool for the Animata redemption program.",
      link_label: "View redeem contract",
      link_url:
        "https://basescan.org/address/0x71065b775a590c43933F10c0055dc7d74AfAbb0e#asset-tokens"
    },
    %{
      rank: 5,
      label: "Unknown Whale",
      address: "0x301F742573c76ee107cb8E263f2D5c009EcBFB28",
      short: "0x301F...fB28",
      percent: "2.50%",
      amount: "2.5B",
      description: "Unknown holder who accumulated 2.5% of supply"
    },
    %{
      rank: 6,
      label: "Protocol-owned Liquidity on Hydrex",
      address: "0x46F4149cEA5556BD013D4f031D3E3B65573FC002",
      short: "0x46F4...C002",
      percent: "0.88%",
      amount: "880.2M",
      description:
        "Protocol-owned liquidity on Hydrex. These tokens were acquired from buybacks and sit in the liquidity address tied to that pool.",
      link_label: "View Hydrex pool",
      link_url: "https://www.hydrex.fi/pools?search=regent"
    }
  ]

  @allocations [
    %{
      title: "20% to Clanker Deployment",
      body: [
        "On Nov 6th, 2025, the $REGENT token launched via Clanker. A 4.65 eth creator buy, split between 16 individuals, acquired 6.5% of tokens. These are locked until May 6th, 2026 and become liquid then.",
        "Consequently 13.5% of tokens were circulating immediately, and the full 20% will be circulating on May 6th."
      ]
    },
    %{
      title: "40% Regents Labs Multisig",
      bullets: [
        %{
          label: "10% for Animata program",
          details: [
            "Locked onchain in the redemption contract immediately on admin receipt.",
            "Accessible to buy for Animata pass holders starting 3 days after the Clanker token launch.",
            "As of Feb 11th 2026, 71.5% of NFTs had been redeemed, leading to 7.15% of the 10% becoming liquid."
          ]
        },
        %{
          label: "10% for Agent Coin fee rewards",
          details: [
            "A new form of revenue mining that rewards agent creators who bring protocol revenue.",
            "Locked onchain in the Regent contracts once those smart contracts are completed and audited."
          ]
        },
        %{
          label: "10% OTC for protocol growth and subsidizing agent API costs.",
          details: []
        },
        %{
          label: "10% Ecosystem Fund",
          details: [
            "Allocated to reward agent builders and high-value partnerships."
          ]
        }
      ]
    },
    %{
      title: "40% Clanker Vault - Locked onchain for 1 year then vesting over 2 years",
      bullets: [
        %{
          label: "20% Company Treasury",
          details: [
            "Used for employee incentives and OTC deals."
          ]
        },
        %{
          label: "20% Sovereign Agent Incentives",
          details: [
            "These tokens are only to be used when economic agents are clearly here and a quorum of $REGENT holders agrees to it.",
            "The intent is to hold these until there is a credible way to reward sovereign agents for participating in the Regent ecosystem."
          ]
        }
      ],
      link_label: "View on Clanker",
      link_url: "https://clanker.world/clanker/0x6f89bcA4eA5931EdFCB09786267b251DeE752b07"
    }
  ]

  def holders, do: @holders
  def allocations, do: @allocations
end
