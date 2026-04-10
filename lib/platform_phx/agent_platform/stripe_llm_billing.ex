defmodule PlatformPhx.AgentPlatform.StripeLlmBilling do
  @moduledoc false

  alias PlatformPhx.Accounts.HumanUser
  alias PlatformPhx.AgentPlatform.LlmUsageEvent
  alias PlatformPhx.RuntimeConfig

  def create_checkout_session(%HumanUser{} = human) do
    with {:ok, secret_key} <- fetch_secret_key(),
         {:ok, pricing_plan_id} <- fetch_pricing_plan_id(),
         {:ok, success_url} <- fetch_success_url(),
         {:ok, cancel_url} <- fetch_cancel_url() do
      client().create_checkout_session(%{
        secret_key: secret_key,
        pricing_plan_id: pricing_plan_id,
        success_url: success_url,
        cancel_url: cancel_url,
        customer_id: human.stripe_customer_id,
        metadata: %{"human_user_id" => Integer.to_string(human.id)}
      })
    end
  end

  def parse_webhook_event(raw_body, headers) do
    with {:ok, secret} <- fetch_webhook_secret(),
         :ok <- verify_signature(raw_body, Map.get(headers, "stripe-signature"), secret),
         {:ok, payload} <- Jason.decode(raw_body),
         {:ok, event} <- normalize_event(payload) do
      {:ok, event}
    end
  end

  def report_usage(%LlmUsageEvent{} = usage_event) do
    with {:ok, secret_key} <- fetch_secret_key(),
         {:ok, meter_id} <- fetch_meter_id() do
      client().report_usage(%{
        secret_key: secret_key,
        meter_id: meter_id,
        usage_event: usage_event
      })
    end
  end

  def client, do: Application.get_env(:platform_phx, :stripe_llm_client, __MODULE__.HttpClient)

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
    case RuntimeConfig.stripe_llm_pricing_plan_id() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_LLM_PRICING_PLAN_ID"}}
      value -> {:ok, value}
    end
  end

  defp fetch_success_url do
    case RuntimeConfig.stripe_llm_success_url() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_LLM_SUCCESS_URL"}}
      value -> {:ok, value}
    end
  end

  defp fetch_cancel_url do
    case RuntimeConfig.stripe_llm_cancel_url() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_LLM_CANCEL_URL"}}
      value -> {:ok, value}
    end
  end

  defp fetch_meter_id do
    case RuntimeConfig.stripe_ai_meter_id() do
      nil -> {:error, {:unavailable, "Server missing STRIPE_AI_METER_ID"}}
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

  defp normalize_event(%{
         "id" => id,
         "type" => type,
         "data" => %{"object" => object}
       }) do
    {:ok,
     %{
       "event_id" => id,
       "event_type" => type,
       "customer_id" => object["customer"],
       "subscription_id" =>
         object["subscription"] || object["id"] ||
           get_in(object, ["items", "data", Access.at(0), "subscription"]),
       "subscription_status" => object["status"],
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

    def create_checkout_session(params) do
      form = [
        {"checkout_items[0][type]", "pricing_plan_subscription_item"},
        {"checkout_items[0][pricing_plan_subscription_item][pricing_plan]",
         params.pricing_plan_id},
        {"success_url", params.success_url},
        {"cancel_url", params.cancel_url},
        {"mode", "subscription"},
        {"metadata[human_user_id]", params.metadata["human_user_id"]}
      ]

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
           {:external, :stripe, "Stripe checkout failed with status #{status}: #{inspect(body)}"}}

        {:error, error} ->
          {:error, {:external, :stripe, Exception.message(error)}}
      end
    end

    def report_usage(%{usage_event: usage_event, meter_id: meter_id, secret_key: secret_key}) do
      form = [
        {"event_name", meter_id},
        {"payload[customer_id]", usage_event.human_user.stripe_customer_id || ""},
        {"payload[value]",
         Integer.to_string(
           usage_event.input_tokens + usage_event.output_tokens + usage_event.cached_tokens
         )},
        {"payload[stripe_customer_id]", usage_event.human_user.stripe_customer_id || ""},
        {"payload[model]", usage_event.model},
        {"payload[input_tokens]", Integer.to_string(usage_event.input_tokens)},
        {"payload[output_tokens]", Integer.to_string(usage_event.output_tokens)},
        {"payload[cached_tokens]", Integer.to_string(usage_event.cached_tokens)}
      ]

      case Req.post("https://api.stripe.com/v1/billing/meter_events",
             form: form,
             auth: {:bearer, secret_key}
           ) do
        {:ok, %{status: status, body: %{"identifier" => identifier}}} when status in 200..299 ->
          {:ok, %{meter_event_id: identifier}}

        {:ok, %{status: status, body: body}} ->
          {:error,
           {:external, :stripe,
            "Stripe usage reporting failed with status #{status}: #{inspect(body)}"}}

        {:error, error} ->
          {:error, {:external, :stripe, Exception.message(error)}}
      end
    end
  end
end
