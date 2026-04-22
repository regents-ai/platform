defmodule PlatformPhxWeb.PublicPageCatalogTest do
  use ExUnit.Case, async: true

  alias PlatformPhxWeb.PublicPageCatalog
  alias PlatformPhxWeb.RegentCliPage

  test "cli markdown is sourced from the canonical CLI page module" do
    assert PublicPageCatalog.cli_markdown() == RegentCliPage.page_markdown()
  end
end
