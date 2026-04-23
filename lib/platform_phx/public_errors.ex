defmodule PlatformPhx.PublicErrors do
  @moduledoc false

  def profile_save,
    do: "We could not save that profile. Check the name and try again."

  def staking_action,
    do: "Could not prepare that staking action right now."

  def collectible_lookup,
    do: "Collectible lookup is unavailable right now."

  def name_claiming,
    do: "Name claiming is unavailable right now."

  def payment_verification,
    do: "Payment verification is unavailable right now."

  def billing,
    do: "Billing is unavailable right now."

  def trust_approval,
    do: "Trust approval could not be completed right now."

  def company_runtime,
    do: "Company controls are unavailable right now."
end
