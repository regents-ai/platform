defmodule PlatformPhx.AgentPlatform.Formation.Readiness do
  @moduledoc false

  def payload(context) when is_map(context) do
    steps = steps(context)

    %{
      ready: ready?(steps),
      blocked_step: Enum.find(steps, &(&1.status in ["needs_action", "waiting"])),
      steps: steps
    }
  end

  def steps(context) when is_map(context) do
    authenticated? = context.authenticated
    wallet_connected? = context.wallet_connected?
    eligible? = context.eligible
    template_ready? = context.template_ready?
    company_opened? = context.owned_companies != []
    launch_active? = active_formation?(context.active_formations)
    name_ready? = context.available_claims != [] or company_opened? or launch_active?
    billing_account = context.billing_account
    billing_ready? = Map.fetch!(billing_account, :connected) == true
    billing_status = Map.fetch!(billing_account, :status)

    [
      identity_step(authenticated?),
      wallet_step(authenticated?, wallet_connected?),
      access_step(wallet_connected?, eligible?),
      name_step(eligible?, name_ready?),
      billing_step(name_ready?, billing_ready?, billing_status),
      template_step(billing_ready?, template_ready?),
      company_step(billing_ready? and template_ready?, company_opened?, launch_active?),
      launch_queue_step(
        billing_ready? and template_ready?,
        company_opened?,
        launch_active?
      )
    ]
  end

  defp ready?(steps) do
    Enum.all?(steps, &(&1.status in ["complete", "ready"]))
  end

  defp active_formation?(active_formations) when is_list(active_formations) do
    Enum.any?(active_formations, &(&1.status in ["queued", "running"]))
  end

  defp active_formation?(_active_formations), do: false

  defp identity_step(true) do
    step(:identity, "Signed in", "complete", "You are signed in.", nil, nil)
  end

  defp identity_step(false) do
    step(
      :identity,
      "Sign in",
      "needs_action",
      "Sign in to start company setup.",
      "Go to access",
      "/app/access"
    )
  end

  defp wallet_step(_authenticated?, true) do
    step(:wallet, "Wallet", "complete", "A wallet is connected.", nil, nil)
  end

  defp wallet_step(false, false) do
    step(
      :wallet,
      "Wallet",
      "waiting",
      "Sign in so your wallet can be checked.",
      "Go to access",
      "/app/access"
    )
  end

  defp wallet_step(true, false) do
    step(
      :wallet,
      "Wallet",
      "needs_action",
      "Connect a wallet before company setup can continue.",
      "Go to access",
      "/app/access"
    )
  end

  defp access_step(_wallet_connected?, true) do
    step(:access, "Access", "complete", "This wallet has company access.", nil, nil)
  end

  defp access_step(false, false) do
    step(
      :access,
      "Access",
      "waiting",
      "Connect a wallet before access can be checked.",
      "Go to access",
      "/app/access"
    )
  end

  defp access_step(true, false) do
    step(
      :access,
      "Access",
      "needs_action",
      "This wallet needs a qualifying pass before company setup can continue.",
      "Go to access",
      "/app/access"
    )
  end

  defp name_step(_eligible?, true) do
    step(:name, "Company name", "complete", "A claimed name is ready to use.", nil, nil)
  end

  defp name_step(false, false) do
    step(
      :name,
      "Company name",
      "waiting",
      "Confirm company access before choosing a name.",
      "Go to access",
      "/app/access"
    )
  end

  defp name_step(true, false) do
    step(
      :name,
      "Company name",
      "needs_action",
      "Claim a name before adding billing.",
      "Go to identity",
      "/app/identity"
    )
  end

  defp billing_step(_name_ready?, true, _billing_status) do
    step(:billing, "Billing", "complete", "Billing is active.", nil, nil)
  end

  defp billing_step(true, false, "checkout_open") do
    step(
      :billing,
      "Billing",
      "waiting",
      "Billing setup is being confirmed.",
      "Check billing",
      "/app/billing"
    )
  end

  defp billing_step(false, false, _billing_status) do
    step(
      :billing,
      "Billing",
      "waiting",
      "Claim a name before billing can be activated.",
      "Go to identity",
      "/app/identity"
    )
  end

  defp billing_step(true, false, _billing_status) do
    step(
      :billing,
      "Billing",
      "needs_action",
      "Activate billing before opening a company.",
      "Go to billing",
      "/app/billing"
    )
  end

  defp template_step(false, _template_ready?) do
    step(
      :template,
      "Launch plan",
      "waiting",
      "Activate billing before the launch plan can be used.",
      "Go to billing",
      "/app/billing"
    )
  end

  defp template_step(true, true) do
    step(:template, "Launch plan", "complete", "The launch plan is ready.", nil, nil)
  end

  defp template_step(true, false) do
    step(
      :template,
      "Launch plan",
      "waiting",
      "The launch plan needs attention before company opening.",
      nil,
      nil
    )
  end

  defp company_step(_launch_ready?, _company_opened?, true) do
    step(
      :company,
      "Company",
      "waiting",
      "Your company is opening now.",
      "View progress",
      "/app/formation"
    )
  end

  defp company_step(_launch_ready?, true, false) do
    step(:company, "Company", "complete", "A company is open.", nil, nil)
  end

  defp company_step(true, false, false) do
    step(
      :company,
      "Company",
      "ready",
      "You can open the company now.",
      "Open company",
      "/app/formation"
    )
  end

  defp company_step(false, false, false) do
    step(
      :company,
      "Company",
      "waiting",
      "Finish setup before opening a company.",
      "Open setup",
      "/app/formation"
    )
  end

  defp launch_queue_step(_launch_ready?, _company_opened?, true) do
    step(
      :launch_queue,
      "Launch queue",
      "waiting",
      "Company opening is already in progress.",
      "View progress",
      "/app/formation"
    )
  end

  defp launch_queue_step(_launch_ready?, true, false) do
    step(
      :launch_queue,
      "Launch queue",
      "complete",
      "The company has moved through launch.",
      nil,
      nil
    )
  end

  defp launch_queue_step(true, false, false) do
    step(
      :launch_queue,
      "Launch queue",
      "ready",
      "Launch can start when you open the company.",
      "Open company",
      "/app/formation"
    )
  end

  defp launch_queue_step(false, false, false) do
    step(
      :launch_queue,
      "Launch queue",
      "waiting",
      "Finish setup before launch can start.",
      "Open setup",
      "/app/formation"
    )
  end

  defp step(key, label, status, message, action_label, action_path) do
    %{
      key: Atom.to_string(key),
      label: label,
      status: status,
      message: message,
      action_label: action_label,
      action_path: action_path
    }
  end
end
