defmodule PlatformPhx.Beta.Smoke do
  @moduledoc false

  @default_timeout 8_000
  @public_paths [
    {"home", "/"},
    {"app_entry", "/app"},
    {"cli", "/cli"},
    {"docs", "/docs"},
    {"token_staking", "/token-info"},
    {"billing", "/app/billing"},
    {"formation", "/app/formation"}
  ]

  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    _ = Application.ensure_all_started(:telemetry)
    _ = Application.ensure_all_started(:req)

    env = Keyword.get(opts, :env, &System.get_env/1)
    host = opts |> Keyword.get(:host) |> normalize_host(env)
    http_client = Keyword.get(opts, :http_client, Req)
    mobile? = mobile_requested?(opts, env)

    checks =
      @public_paths
      |> Enum.map(&page_check(http_client, host, &1))
      |> Kernel.++([
        disabled_beta_actions_check(http_client, host, env),
        public_company_check(http_client, host, Keyword.get(opts, :company_slug), env),
        signed_staking_api_check(http_client, host, env),
        mobile_browser_check(host, env, mobile?)
      ])

    %{
      generated_at: now_iso(),
      host: host,
      status: overall_status(checks),
      checks: checks
    }
  end

  defp page_check(http_client, host, {name, path}) do
    case get(http_client, url(host, path), []) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        if expected_page_body?(name, body) do
          check(name, "pass", "#{human_name(name)} loaded.")
        else
          check(name, "blocked", "#{human_name(name)} loaded without the expected page content.")
        end

      {:ok, %{status: status}} ->
        check(name, "blocked", "#{human_name(name)} returned HTTP #{status}.")

      {:error, _reason} ->
        check(name, "blocked", "#{human_name(name)} could not be reached.")
    end
  end

  defp public_company_check(http_client, host, company_slug, env) do
    slug = company_slug || env_value(env, "PLATFORM_BETA_COMPANY_SLUG")

    if present?(slug) do
      case get(http_client, url(host, "/agents/#{slug}"), []) do
        {:ok, %{status: status}} when status in 200..299 ->
          check("public_company_page", "pass", "Configured public company page loaded.")

        {:ok, %{status: status}} ->
          check(
            "public_company_page",
            "blocked",
            "Configured public company page returned HTTP #{status}."
          )

        {:error, _reason} ->
          check(
            "public_company_page",
            "blocked",
            "Configured public company page could not be reached."
          )
      end
    else
      check(
        "public_company_page",
        "not_included",
        "Set PLATFORM_BETA_COMPANY_SLUG to smoke test one public company page."
      )
    end
  end

  defp disabled_beta_actions_check(http_client, host, env) do
    if formation_enabled?(env) do
      check(
        "disabled_beta_actions",
        "not_included",
        "Hosted company opening is enabled for this run."
      )
    else
      billing =
        disabled_page_copy?(
          http_client,
          host,
          "/app/billing",
          "Hosted company billing is not available right now."
        )

      formation =
        disabled_page_copy?(
          http_client,
          host,
          "/app/formation",
          "Hosted company opening is not available right now."
        )

      if billing == :ok and formation == :ok do
        check(
          "disabled_beta_actions",
          "pass",
          "Hosted billing and company opening actions stayed unavailable."
        )
      else
        check(
          "disabled_beta_actions",
          "blocked",
          "Hosted billing or company opening did not show the expected unavailable state."
        )
      end
    end
  end

  defp disabled_page_copy?(http_client, host, path, expected_copy) do
    case get(http_client, url(host, path), []) do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        if String.contains?(body, expected_copy), do: :ok, else: :error

      _other ->
        :error
    end
  end

  defp signed_staking_api_check(http_client, host, env) do
    case env_value(env, "PLATFORM_BETA_SIWA_RECEIPT") do
      value when is_binary(value) and value != "" ->
        headers = [{"x-siwa-receipt", value}]

        case get(http_client, url(host, "/v1/agent/regent/staking"), headers) do
          {:ok, %{status: status, body: body}} when status in 200..299 ->
            if ok_body?(body) do
              check("staking_api", "pass", "$REGENT staking API accepted the signed request.")
            else
              check(
                "staking_api",
                "blocked",
                "$REGENT staking API response was not the expected success shape."
              )
            end

          {:ok, %{status: status}} ->
            check("staking_api", "blocked", "$REGENT staking API returned HTTP #{status}.")

          {:error, _reason} ->
            check("staking_api", "blocked", "$REGENT staking API could not be reached.")
        end

      _other ->
        check(
          "staking_api",
          "not_included",
          "Set PLATFORM_BETA_SIWA_RECEIPT to smoke test signed staking."
        )
    end
  end

  defp mobile_browser_check(_host, _env, false) do
    check("mobile_browser", "not_included", "Mobile browser smoke was not requested.")
  end

  defp mobile_browser_check(host, env, true) do
    case env_value(env, "PLATFORM_CHROMIUM_PATH") do
      value when is_binary(value) and value != "" ->
        run_mobile_browser(host, value)

      _other ->
        check(
          "mobile_browser",
          "blocked",
          "Set PLATFORM_CHROMIUM_PATH to run mobile browser smoke."
        )
    end
  end

  defp run_mobile_browser(host, executable_path) do
    root = Path.expand("../../..", __DIR__)
    script = Path.join(root, "assets/js/smoke/mobile-smoke.mjs")

    case System.cmd("node", [script, host],
           cd: root,
           env: [{"PLATFORM_CHROMIUM_PATH", executable_path}],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        check("mobile_browser", "pass", "Mobile browser smoke passed.")

      {output, _status} ->
        check("mobile_browser", "blocked", clean_mobile_output(output))
    end
  end

  defp get(http_client, target_url, headers) do
    response =
      http_client.get(target_url,
        headers: headers,
        receive_timeout: @default_timeout,
        retry: false
      )

    case response do
      {:ok, %{status: _status} = result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      %{status: _status} = result -> {:ok, result}
      _other -> {:error, :invalid_response}
    end
  rescue
    _error -> {:error, :request_failed}
  end

  defp expected_page_body?(_name, body) when not is_binary(body), do: true
  defp expected_page_body?("home", body), do: String.contains?(body, "Regents")
  defp expected_page_body?("cli", body), do: String.contains?(body, "Regents CLI")
  defp expected_page_body?("docs", body), do: String.contains?(body, "Docs")
  defp expected_page_body?("token_staking", body), do: String.contains?(body, "$REGENT")
  defp expected_page_body?(_name, _body), do: true

  defp ok_body?(%{"ok" => true}), do: true
  defp ok_body?(%{ok: true}), do: true

  defp ok_body?(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> ok_body?(decoded)
      {:error, _reason} -> false
    end
  end

  defp ok_body?(_body), do: false

  defp normalize_host(nil, env) do
    cond do
      present?(env_value(env, "PLATFORM_BETA_HOST")) ->
        normalize_host(env_value(env, "PLATFORM_BETA_HOST"), env)

      present?(env_value(env, "PHX_HOST")) ->
        normalize_host("https://#{env_value(env, "PHX_HOST")}", env)

      true ->
        "http://localhost:4000"
    end
  end

  defp normalize_host(value, _env) when is_binary(value) do
    value
    |> String.trim()
    |> String.trim_trailing("/")
    |> case do
      "http://" <> _rest = host -> host
      "https://" <> _rest = host -> host
      host -> "https://#{host}"
    end
  end

  defp url(host, path), do: host <> path

  defp mobile_enabled?(env) do
    env
    |> env_value("PLATFORM_BETA_MOBILE_SMOKE")
    |> case do
      value when value in ["1", "true", "TRUE", "yes", "YES"] -> true
      _other -> false
    end
  end

  defp mobile_requested?(opts, env) do
    case Keyword.fetch(opts, :mobile?) do
      {:ok, value} -> value == true
      :error -> mobile_enabled?(env)
    end
  end

  defp formation_enabled?(env) do
    env
    |> env_value("AGENT_FORMATION_ENABLED")
    |> case do
      value when value in ["1", "true", "TRUE", "yes", "YES"] -> true
      value when value in ["0", "false", "FALSE", "no", "NO"] -> false
      _other -> false
    end
  end

  defp env_value(env, name) when is_function(env, 1), do: env.(name)
  defp env_value(env, name) when is_map(env), do: Map.get(env, name)

  defp env_value(env, name) when is_list(env) do
    env
    |> Map.new()
    |> Map.get(name)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp overall_status(checks) do
    if Enum.any?(checks, &(&1.status == "blocked")), do: "blocked", else: "pass"
  end

  defp check(name, status, message), do: %{name: name, status: status, message: message}

  defp human_name(name) do
    name
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp clean_mobile_output(output) do
    output
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "Mobile browser smoke failed."
      message -> String.slice(message, 0, 240)
    end
  end

  defp now_iso do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
