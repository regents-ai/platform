defmodule PlatformPhx.Security.Redactor do
  @moduledoc false

  @redacted "[redacted]"
  @sensitive_key_fragments [
    "api_key",
    "apikey",
    "auth",
    "bearer",
    "calendar",
    "chat_transcript",
    "client_secret",
    "credential",
    "inbox",
    "jwt",
    "oauth",
    "password",
    "private_key",
    "private_memory",
    "refresh_token",
    "secret",
    "session",
    "ssh_key",
    "token",
    "transcript",
    "webhook_secret"
  ]

  @content_markers [
    "BEGIN PRIVATE KEY",
    "BEGIN OPENSSH PRIVATE KEY",
    "xoxb-",
    "sk-",
    "ghp_",
    "AKIA",
    "PRIVATE MEMORY:",
    "CHAT TRANSCRIPT:",
    "INBOX:",
    "CALENDAR:"
  ]

  def redact_event_payload(payload) when is_map(payload), do: redact_map(payload)
  def redact_event_payload(_payload), do: %{}

  defp redact_map(payload) do
    Map.new(payload, fn {key, value} ->
      if sensitive_key?(key) do
        {key, @redacted}
      else
        {key, redact_value(value)}
      end
    end)
  end

  defp redact_value(value) when is_map(value), do: redact_map(value)
  defp redact_value(value) when is_list(value), do: Enum.map(value, &redact_value/1)

  defp redact_value(value) when is_binary(value) do
    if sensitive_content?(value), do: @redacted, else: value
  end

  defp redact_value(value), do: value

  defp sensitive_key?(key) do
    normalized =
      key
      |> to_string()
      |> String.downcase()

    Enum.any?(@sensitive_key_fragments, &String.contains?(normalized, &1))
  end

  defp sensitive_content?(value) do
    Enum.any?(@content_markers, &String.contains?(value, &1))
  end
end
