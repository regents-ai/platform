defmodule PlatformPhx.AgentPlatform.ArtifactTest do
  use PlatformPhx.DataCase, async: true

  alias PlatformPhx.AgentPlatform.Artifact

  test "accepts http and https artifact URLs" do
    changeset =
      Artifact.changeset(%Artifact{}, %{
        agent_id: 1,
        title: "Public run",
        summary: "Published output",
        url: "https://example.com/output",
        visibility: "public"
      })

    assert changeset.valid?

    http_changeset =
      Artifact.changeset(%Artifact{}, %{
        agent_id: 1,
        title: "Local mirror",
        summary: "Published output",
        url: "http://example.com/output",
        visibility: "public"
      })

    assert http_changeset.valid?
  end

  test "rejects non-http artifact URLs" do
    changeset =
      Artifact.changeset(%Artifact{}, %{
        agent_id: 1,
        title: "Bad link",
        summary: "Published output",
        url: "javascript:alert('xss')",
        visibility: "public"
      })

    refute changeset.valid?
    assert errors_on(changeset) == %{url: ["must be an http or https URL"]}
  end
end
