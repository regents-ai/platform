defmodule PlatformPhxWeb.Discovery do
  @moduledoc false

  import Ecto.Query

  alias PlatformPhx.Repo
  alias PlatformPhx.AgentPlatform.Subdomain
  alias PlatformPhxWeb.PublicPageCatalog
  alias PlatformPhxWeb.SiteUrl

  @ai_crawlers ["GPTBot", "OAI-SearchBot", "Claude-Web", "Google-Extended"]

  def robots_txt do
    [
      "User-agent: *",
      "Allow: /",
      "",
      Enum.map(@ai_crawlers, fn crawler ->
        "User-agent: #{crawler}\nAllow: /"
      end),
      "",
      "Content-Signal: search=yes, ai-input=yes, ai-train=yes",
      "Sitemap: #{SiteUrl.absolute_url("/sitemap.xml")}"
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  def sitemap_xml do
    urls =
      PublicPageCatalog.public_entry_paths()
      |> Kernel.++(corpus_paths())
      |> Enum.map(&SiteUrl.absolute_url/1)
      |> Kernel.++(company_home_urls())
      |> Enum.uniq()
      |> Enum.sort()

    entries =
      Enum.map_join(urls, "\n", fn url ->
        "  <url><loc>#{url}</loc></url>"
      end)

    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">),
      entries,
      "</urlset>"
    ]
    |> Enum.join("\n")
  end

  def api_catalog do
    %{
      "linkset" => [
        %{
          "anchor" => SiteUrl.absolute_url("/api"),
          "item" => [
            %{
              "href" => SiteUrl.absolute_url("/api-contract.openapiv3.yaml"),
              "rel" => "service-desc",
              "type" => "application/yaml"
            },
            %{
              "href" => SiteUrl.absolute_url("/docs"),
              "rel" => "service-doc",
              "type" => "text/html"
            },
            %{
              "href" => SiteUrl.absolute_url("/learn/what-is-regents/"),
              "rel" => "service-doc",
              "type" => "text/html",
              "title" => "Regents public corpus"
            },
            %{
              "href" => SiteUrl.absolute_url("/llms.txt"),
              "rel" => "describedby",
              "type" => "text/plain"
            },
            %{
              "href" => SiteUrl.absolute_url("/regents-facts.json"),
              "rel" => "describedby",
              "type" => "application/json"
            },
            %{
              "href" => SiteUrl.absolute_url("/healthz"),
              "rel" => "status",
              "type" => "text/plain"
            }
          ]
        }
      ]
    }
  end

  def agent_card do
    %{
      "name" => "Regents Site Agent",
      "version" => app_version(),
      "description" =>
        "Read-only discovery surface for the Regents website, its public contracts, and the published Regents CLI skill.",
      "documentationUrl" => SiteUrl.absolute_url("/docs"),
      "corpusUrl" => SiteUrl.absolute_url("/learn/what-is-regents/"),
      "factsUrl" => SiteUrl.absolute_url("/regents-facts.json"),
      "url" => SiteUrl.absolute_url("/"),
      "supportedInterfaces" => [
        %{
          "name" => "public-discovery",
          "serviceUrl" => SiteUrl.absolute_url("/"),
          "transportProtocol" => "https",
          "description" =>
            "Public discovery documents and entry pages for the Regents website and Regents CLI."
        }
      ],
      "capabilities" => %{
        "discovery" => true,
        "readOnly" => true
      },
      "skills" => [
        %{
          "id" => "regents-cli",
          "name" => "Regents CLI",
          "description" => PublicPageCatalog.regents_cli_skill_description(),
          "url" => SiteUrl.absolute_url("/agent-skills/regents-cli.md")
        }
      ]
    }
  end

  def agent_skills_index do
    skill_body = PublicPageCatalog.regents_cli_skill_markdown()

    %{
      "$schema" => "https://agentskills.io/schemas/agent-skills-index-v0.2.0.json",
      "skills" => [
        %{
          "id" => "regents-cli",
          "name" => "Regents CLI",
          "type" => "skill-md",
          "description" => PublicPageCatalog.regents_cli_skill_description(),
          "url" => SiteUrl.absolute_url("/agent-skills/regents-cli.md"),
          "sha256" => sha256_hex(skill_body)
        }
      ]
    }
  end

  def mcp_server_card do
    %{
      "serverInfo" => %{
        "name" => "Regents Discovery",
        "version" => app_version()
      },
      "description" =>
        "Public discovery card for the Regents website resources, contracts, and the published Regents CLI skill.",
      "documentationUrl" => SiteUrl.absolute_url("/docs"),
      "capabilities" => %{
        "resources" => true,
        "tools" => false,
        "prompts" => false
      },
      "transports" => [],
      "resources" => [
        %{
          "name" => "API catalog",
          "url" => SiteUrl.absolute_url("/.well-known/api-catalog")
        },
        %{
          "name" => "Regents CLI skill",
          "url" => SiteUrl.absolute_url("/agent-skills/regents-cli.md")
        },
        %{
          "name" => "API contract",
          "url" => SiteUrl.absolute_url("/api-contract.openapiv3.yaml")
        },
        %{
          "name" => "Regents public corpus",
          "url" => SiteUrl.absolute_url("/learn/what-is-regents/")
        },
        %{
          "name" => "Regents facts",
          "url" => SiteUrl.absolute_url("/regents-facts.json")
        }
      ]
    }
  end

  def project_file_contents(filename)
      when filename in ["api-contract.openapiv3.yaml", "cli-contract.yaml"] do
    PlatformPhx.Contracts.contents!(filename)
  end

  def regents_cli_skill, do: PublicPageCatalog.regents_cli_skill_markdown()

  def sha256_hex(body) when is_binary(body) do
    :sha256
    |> :crypto.hash(body)
    |> Base.encode16(case: :lower)
  end

  defp company_home_urls do
    from(subdomain in Subdomain,
      join: agent in assoc(subdomain, :agent),
      where: subdomain.active == true and agent.status == "published",
      order_by: [asc: subdomain.hostname],
      select: subdomain.hostname
    )
    |> Repo.all()
    |> Enum.map(&SiteUrl.absolute_url("/", &1))
  end

  def corpus_paths do
    [
      "/learn/what-is-regents/",
      "/learn/agent-companies/",
      "/learn/sovereign-agents/",
      "/learn/public-proof/",
      "/learn/agent-native-capital/",
      "/learn/continuous-clearing-auctions/",
      "/learn/recognized-stablecoin-revenue/",
      "/learn/source-of-truth-discipline/",
      "/glossary/regent/",
      "/glossary/agent-company/",
      "/glossary/sovereign-agent/",
      "/glossary/public-proof/",
      "/glossary/siwa/",
      "/glossary/revsplit/",
      "/glossary/recognized-revenue/",
      "/glossary/continuous-clearing-auction/",
      "/glossary/agent-id/",
      "/source/regents-purpose/",
      "/source/platform-purpose/",
      "/source/regents-cli-purpose/",
      "/source/techtree-purpose/",
      "/source/autolaunch-purpose/",
      "/source/siwa-purpose/",
      "/source/mobile-status/",
      "/source/source-of-truth-matrix/",
      "/updates/2026-04-29-build-note/",
      "/llms.txt",
      "/ai-index.md",
      "/regents-facts.json"
    ]
  end

  defp app_version do
    :platform_phx
    |> Application.spec(:vsn)
    |> to_string()
  end
end
