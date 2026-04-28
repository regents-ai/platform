defmodule PlatformPhxWeb.AppComponents.SetupPresenterTest do
  use ExUnit.Case, async: true

  alias PlatformPhxWeb.AppComponents.SetupPresenter

  test "company snapshot stays open when a company exists without an active launch" do
    snapshot = SetupPresenter.setup_snapshot_from_company(%{id: 1}, nil)

    assert snapshot.company_opened? == true
    assert snapshot.company_opening? == false
  end

  test "company snapshot shows opening while launch is still active" do
    snapshot =
      SetupPresenter.setup_snapshot_from_company(%{id: 1}, %{status: "running"})

    assert snapshot.company_opened? == false
    assert snapshot.company_opening? == true
  end
end
