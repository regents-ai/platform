defmodule PlatformPhxWeb.Api.StripeWebhookController do
  use PlatformPhxWeb, :controller

  alias PlatformPhx.AgentPlatform.Formation
  alias PlatformPhxWeb.ApiErrors

  def create(conn, _params) do
    raw_body = conn.assigns[:raw_body] || ""

    headers =
      conn.req_headers
      |> Enum.into(%{}, fn {key, value} -> {String.downcase(key), value} end)

    Formation.handle_stripe_webhook(raw_body, headers)
    |> then(&ApiErrors.respond(conn, &1))
  end
end
