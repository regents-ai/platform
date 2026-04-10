defmodule PlatformPhx.AgentPlatform.StripeBilling do
  @moduledoc false

  alias PlatformPhx.AgentPlatform.BillingAccount
  alias PlatformPhx.AgentPlatform.SpriteUsageRecord
  alias PlatformPhx.RuntimeConfig

  def create_billing_setup_checkout_session(%BillingAccount{} = account, human_user_id, opts) do
    with {:ok, secret_key} <- fetch_secret_key(),
         {:ok, pricing_plan_id} <- fetch_pricing_plan_id(),
         {:ok, success_url} <- fetch_setup_url(opts, :success_url),
         {:ok, cancel_url} <- fetch_setup_url(opts, :cancel_url) do
      client().create_billing_setup_checkout_session(%{
        secret_key: secret_key,
        pricing_plan_id: pricing_plan_id,
        success_url: success_url,
        cancel_url: cancel_url,
        customer_id: account.stripe_customer_id,
        metadata: %{
          "checkout_kind" => "billing_setup",
          "human_user_id" => Integer.to_string(human_user_id)
        }
      })
    end
  end

  def create_topup_checkout_session(%BillingAccount{} = account, amount_usd_cents) do
    with {:ok, secret_key} <- fetch_secret_key(),
         {:ok, success_url} <- fetch_topup_success_url(),
         {:ok, cancel_url} <- fetch_topup_cancel_url() do
      client().create_topup_checkout_session(%{
        secret_key: secret_key,
        success_url: success_url,
        cancel_url: cancel_url,
        customer_id: account.stripe_customer_id,
        amount_usd_cents: amount_usd_cents,
        metadata: %{
          "checkout_kind" => "runtime_topup",
          "billing_account_id" => Integer.to_string(account.id),
          "amount_usd_cents" => Integer.to_string(amount_usd_cents)
        }
      })
    end
  end

  def create_credit_grant(%BillingAccount{} = account, amount_usd_cents, source_ref) do
    with {:ok, secret_key} <- fetch_secret_key() do
      client().create_credit_grant(%{
        secret_key: secret_key,
        customer_id: account.stripe_customer_id,
        amount_usd_cents: amount_usd_cents,
        source_ref: source_ref
      })
    end
  end

  def report_runtime_usage(%SpriteUsageRecord{} = usage_record, customer_id)
      when is_binary(customer_id) do
    with {:ok, secret_key} <- fetch_secret_key(),
         {:ok, meter_event_name} <- fetch_runtime_meter_event_name() do
      client().report_runtime_usage(%{
        secret_key: secret_key,
        meter_event_name: meter_event_name,
        customer_id: customer_id,
        usage_record: usage_record
      })
    end
  end

  def report_runtime_usage(_usage_record, _customer_id),
    do: {:error, {:unavailable, "Stripe customer is missing"}}

  def parse_webhook_event(raw_body, headers) do
    with {:ok, secret} <- fetch_webhook_secret(),
         :ok <- verify_signature(raw_body, Map.get(headers, "stripe-signature"), secret),
         {:ok, payload} <- Jason.decode(raw_body),
         {:ok, event} <- normalize_event(payload) do
      {:ok, event}
    end
  end

  def client,
    do: Application.get_env(:platform_phx, :stripe_billing_client, __MODULE__.HttpClient)

  defp fetch_secret_key do
    case RuntimeConfig.stripe_secret_key() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_SECRET_KEY"}}
      value -> {:ok, value}
    end
  end

  defp fetch_webhook_secret do
    case RuntimeConfig.stripe_webhook_secret() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_WEBHOOK_SECRET"}}
      value -> {:ok, value}
    end
  end

  defp fetch_pricing_plan_id do
    case RuntimeConfig.stripe_billing_pricing_plan_id() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_BILLING_PRICING_PLAN_ID"}}
      value -> {:ok, value}
    end
  end

  defp fetch_setup_url(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" ->
        {:ok, value}

      _ ->
        {:error, {:unavailable, "Server missing billing setup return URL"}}
    end
  end

  defp fetch_topup_success_url do
    case RuntimeConfig.stripe_billing_topup_success_url() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_BILLING_TOPUP_SUCCESS_URL"}}
      value -> {:ok, value}
    end
  end

  defp fetch_topup_cancel_url do
    case RuntimeConfig.stripe_billing_topup_cancel_url() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_BILLING_TOPUP_CANCEL_URL"}}
      value -> {:ok, value}
    end
  end

  defp fetch_runtime_meter_event_name do
    case RuntimeConfig.stripe_runtime_meter_event_name() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_RUNTIME_METER_EVENT_NAME"}}
      value -> {:ok, value}
    end
  end

  defp verify_signature(_raw_body, nil, _secret),
    do: {:error, {:unauthorized, "Stripe signature is missing"}}

  defp verify_signature(raw_body, signature, secret) when is_binary(signature) do
    case parse_signature(signature) do
      {:ok, timestamp, signed_hash} ->
        expected =
          :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}")
          |> Base.encode16(case: :lower)

        if Plug.Crypto.secure_compare(expected, signed_hash) do
          :ok
        else
          {:error, {:unauthorized, "Stripe signature could not be verified"}}
        end

      :error ->
        {:error, {:unauthorized, "Stripe signature could not be parsed"}}
    end
  end

  defp normalize_event(%{"id" => id, "type" => type, "data" => %{"object" => object}}) do
    {:ok,
     %{
       "event_id" => id,
       "event_type" => type,
       "customer_id" => object["customer"],
       "subscription_id" =>
         object["subscription"] || object["id"] ||
           get_in(object, ["items", "data", Access.at(0), "subscription"]),
       "subscription_status" => object["status"],
       "mode" => object["mode"],
       "metadata" => object["metadata"] || %{}
     }}
  end

  defp normalize_event(_payload),
    do: {:error, {:bad_request, "Stripe webhook payload is invalid"}}

  defp parse_signature(signature) do
    parts =
      signature
      |> String.split(",")
      |> Enum.reduce(%{}, fn part, acc ->
        case String.split(part, "=", parts: 2) do
          [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
          _ -> acc
        end
      end)

    with timestamp when is_binary(timestamp) <- Map.get(parts, "t"),
         signed_hash when is_binary(signed_hash) <- Map.get(parts, "v1") do
      {:ok, timestamp, signed_hash}
    else
      _ -> :error
    end
  end

  defmodule HttpClient do
    @moduledoc false
    @checkout_preview_header "2025-09-30.preview;checkout_product_catalog_preview=v1"

    def create_billing_setup_checkout_session(params) do
      form = [
        {"checkout_items[0][type]", "pricing_plan_subscription_item"},
        {"checkout_items[0][pricing_plan_subscription_item][pricing_plan]",
         params.pricing_plan_id},
        {"success_url", params.success_url},
        {"cancel_url", params.cancel_url},
        {"mode", "subscription"}
      ]

      form =
        Enum.reduce(params.metadata, form, fn {key, value}, acc ->
          [{"metadata[#{key}]", value} | acc]
        end)

      form =
        if is_binary(params.customer_id) and params.customer_id != "" do
          [{"customer", params.customer_id} | form]
        else
          form
        end

      case Req.post("https://api.stripe.com/v1/checkout/sessions",
             form: form,
             auth: {:bearer, params.secret_key},
             headers: [{"stripe-version", @checkout_preview_header}]
           ) do
        {:ok, %{status: status, body: %{"url" => url} = body}} when status in 200..299 ->
          {:ok, %{url: url, customer_id: body["customer"]}}

        {:ok, %{status: status, body: body}} ->
          {:error,
           {:external, :stripe,
            "Stripe billing setup failed with status #{status}: #{inspect(body)}"}}

        {:error, error} ->
          {:error, {:external, :stripe, Exception.message(error)}}
      end
    end

    def create_topup_checkout_session(params) do
      form = [
        {"mode", "payment"},
        {"success_url", params.success_url},
        {"cancel_url", params.cancel_url},
        {"line_items[0][price_data][currency]", "usd"},
        {"line_items[0][price_data][product_data][name]", "Regents runtime credit"},
        {"line_items[0][price_data][product_data][description]",
         "Prepaid credit for Regent runtime time."},
        {"line_items[0][price_data][unit_amount]", Integer.to_string(params.amount_usd_cents)},
        {"line_items[0][quantity]", "1"}
      ]

      form =
        Enum.reduce(params.metadata, form, fn {key, value}, acc ->
          [{"metadata[#{key}]", value} | acc]
        end)

      form =
        if is_binary(params.customer_id) and params.customer_id != "" do
          [{"customer", params.customer_id} | form]
        else
          form
        end

      case Req.post("https://api.stripe.com/v1/checkout/sessions",
             form: form,
             auth: {:bearer, params.secret_key}
           ) do
        {:ok, %{status: status, body: %{"url" => url} = body}} when status in 200..299 ->
          {:ok, %{url: url, customer_id: body["customer"]}}

        {:ok, %{status: status, body: body}} ->
          {:error,
           {:external, :stripe, "Stripe top-up failed with status #{status}: #{inspect(body)}"}}

        {:error, error} ->
          {:error, {:external, :stripe, Exception.message(error)}}
      end
    end

    def create_credit_grant(params) do
      form = [
        {"customer", params.customer_id},
        {"name", "Regents runtime credit"},
        {"category", "paid"},
        {"applicability_config[scope][price_type]", "metered"},
        {"amount[type]", "monetary"},
        {"amount[monetary][value]", Integer.to_string(params.amount_usd_cents)},
        {"amount[monetary][currency]", "usd"},
        {"metadata[source_ref]", params.source_ref}
      ]

      case Req.post("https://api.stripe.com/v1/billing/credit_grants",
             form: form,
             auth: {:bearer, params.secret_key}
           ) do
        {:ok, %{status: status, body: %{"id" => id}}} when status in 200..299 ->
          {:ok, %{credit_grant_id: id}}

        {:ok, %{status: status, body: body}} ->
          {:error,
           {:external, :stripe,
            "Stripe credit grant failed with status #{status}: #{inspect(body)}"}}

        {:error, error} ->
          {:error, {:external, :stripe, Exception.message(error)}}
      end
    end

    def report_runtime_usage(params) do
      usage_record = params.usage_record

      form = [
        {"event_name", params.meter_event_name},
        {"payload[stripe_customer_id]", params.customer_id},
        {"payload[value]", Integer.to_string(usage_record.usage_seconds)},
        {"payload[meter_key]", usage_record.meter_key},
        {"payload[agent_id]", Integer.to_string(usage_record.agent_id)}
      ]

      case Req.post("https://api.stripe.com/v1/billing/meter_events",
             form: form,
             auth: {:bearer, params.secret_key}
           ) do
        {:ok, %{status: status, body: %{"identifier" => identifier}}} when status in 200..299 ->
          {:ok, %{meter_event_id: identifier}}

        {:ok, %{status: status, body: body}} ->
          {:error,
           {:external, :stripe,
            "Stripe runtime reporting failed with status #{status}: #{inspect(body)}"}}

        {:error, error} ->
          {:error, {:external, :stripe, Exception.message(error)}}
      end
    end
  end
end
