export type DashboardConfig = {
  privyAppId: string | null;
  privyClientId: string | null;
  baseRpcUrl: string | null;
  redeemerAddress: string | null;
  endpoints: {
    privySession: string;
    privyProfile: string;
    basenamesConfig: string;
    basenamesAllowance: string;
    basenamesAvailability: string;
    basenamesOwned: string;
    basenamesRecent: string;
    basenamesMint: string;
    formation: string;
    formationLlmBillingCheckout: string;
    formationCompanies: string;
    credits: string;
    creditsCheckout: string;
    stripeWebhooks: string;
    opensea: string;
    openseaRedeemStats: string;
  };
};

export interface BasenamesConfigResponse {
  chainId: number;
  parentName: string;
  parentNode: `0x${string}`;
  registryAddress: `0x${string}`;
  l2ResolverAddress: `0x${string}`;
  ensChainId: number;
  ensParentName: string;
  ensParentNode: `0x${string}`;
  ensRegistryAddress: `0x${string}`;
  ensResolverAddress: `0x${string}`;
  priceWei: string;
  paymentRecipient: `0x${string}` | null;
  dbEnabled: boolean;
  mintingEnabled: boolean;
  ensMintingEnabled: boolean;
}

export interface AvailabilityResponse {
  parentName: string;
  label: string;
  fqdn: string;
  node: `0x${string}`;
  owner: `0x${string}`;
  available: boolean;
  basenamesAvailable: boolean;
  reserved?: boolean;
  ensParentName: string;
  ensFqdn: string;
  ensNode: `0x${string}`;
  ensOwner: `0x${string}`;
  ensAvailable: boolean;
}

export interface AllowanceResponse {
  parentName: string;
  parentNode: `0x${string}`;
  address: `0x${string}`;
  snapshotTotal: number;
  freeMintsUsed: number;
  freeMintsRemaining: number;
}

export interface OwnedNamesResponse {
  address: `0x${string}`;
  names: Array<{
    label: string;
    fqdn: string;
    ensFqdn: string | null;
    ensTxHash: `0x${string}` | null;
    isFree: boolean;
    isInUse?: boolean;
    createdAt: string;
  }>;
}

export interface MintResponse {
  ok: boolean;
  fqdn: string;
  label: string;
  txHash: `0x${string}`;
  ensFqdn?: string;
  ensTxHash?: `0x${string}` | null;
  isFree: boolean;
  priceWei: string;
}

export interface RecentNamesResponse {
  names: Array<{
    label: string;
    fqdn: string;
    createdAt: string;
  }>;
}

export interface OpenSeaResponse {
  address: `0x${string}`;
  animata1: number[];
  animata2: number[];
  animataPass: number[];
}

export interface OpenSeaRedeemStatsResponse {
  animata: number;
  "regent-animata-ii": number;
}

export interface LlmBillingStatus {
  status: string;
  connected: boolean;
  provider: string;
  customer_id: string | null;
  subscription_id: string | null;
  model_default: string;
  margin_bps: number;
}

export interface ClaimedNameRecord {
  label: string;
  fqdn: string;
  ens_fqdn: string | null;
  claimed_at: string;
  in_use: boolean;
}

export interface CreditCompanySummary {
  slug: string;
  name: string;
  runtime_status: string;
  sprite_metering_status: string;
  sprite_credit_balance_usd_cents: number;
  sprite_free_until: string | null;
}

export interface SpriteCreditSummary {
  total_balance_usd_cents: number;
  trialing_companies: number;
  paid_companies: number;
  paused_companies: number;
  companies: CreditCompanySummary[];
}

export interface AgentFormationRecord {
  id: number;
  status: string;
  current_step: string;
  attempt_count: number;
  last_error_step: string | null;
  last_error_message: string | null;
  started_at: string | null;
  last_heartbeat_at: string | null;
  completed_at: string | null;
}

export interface AgentCompanyRecord {
  id: number;
  template_key: string;
  name: string;
  slug: string;
  claimed_label: string;
  basename_fqdn: string;
  ens_fqdn: string;
  status: string;
  public_summary: string;
  sprite_name: string | null;
  sprite_url: string | null;
  sprite_service_name: string | null;
  sprite_checkpoint_ref: string | null;
  sprite_created_at: string | null;
  paperclip_url: string | null;
  paperclip_deployment_mode: string | null;
  paperclip_http_port: number | null;
  paperclip_company_id: string | null;
  paperclip_agent_id: string | null;
  hermes_adapter_type: string | null;
  hermes_model: string | null;
  hermes_persist_session: boolean;
  hermes_toolsets: string[];
  hermes_runtime_plugins: string[];
  hermes_shared_skills: string[];
  runtime_status: string;
  checkpoint_status: string;
  runtime_last_checked_at: string | null;
  last_formation_error: string | null;
  stripe_llm_billing_status: string;
  stripe_customer_id: string | null;
  stripe_pricing_plan_subscription_id: string | null;
  sprite_free_until: string | null;
  sprite_credit_balance_usd_cents: number;
  sprite_metering_status: string;
  subdomain: { hostname: string; active: boolean } | null;
  formation: AgentFormationRecord | null;
}

export interface AgentFormationResponse {
  ok: boolean;
  authenticated: boolean;
  wallet_address: `0x${string}` | null;
  eligible: boolean;
  collections: OpenSeaResponse;
  claimed_names: ClaimedNameRecord[];
  available_claims: ClaimedNameRecord[];
  llm_billing: LlmBillingStatus;
  credits: SpriteCreditSummary;
  owned_companies: AgentCompanyRecord[];
  active_formations: AgentFormationRecord[];
}

export interface AgentRuntimeRecord {
  sprite: {
    name: string | null;
    url: string | null;
    status: string;
    owner: string;
    free_until: string | null;
    credit_balance_usd_cents: number;
    metering_status: string;
  };
  paperclip: {
    url: string | null;
    company_id: string | null;
    status: string;
    deployment_mode: string;
    http_port: number;
  };
  hermes: {
    agent_id: string | null;
    status: string;
    adapter_type: string;
    model: string;
    persist_session: boolean;
    toolsets: string[];
    runtime_plugins: string[];
    shared_skills: string[];
  };
  checkpoint: {
    status: string;
  };
  llm_billing: LlmBillingStatus;
}

export interface AgentRuntimeResponse {
  ok: boolean;
  agent: AgentCompanyRecord;
  runtime: AgentRuntimeRecord;
  formation: AgentFormationRecord | null;
}

export interface CreditCheckoutResponse {
  ok: boolean;
  agent: AgentCompanyRecord;
  credits: SpriteCreditSummary;
}

export interface CurrentHumanProfileResponse {
  ok: boolean;
  authenticated: boolean;
  human: {
    id: number;
    privy_user_id: string;
    wallet_address: `0x${string}` | null;
    wallet_addresses: `0x${string}`[];
    display_name: string | null;
    llm_billing: LlmBillingStatus;
  } | null;
  claimed_names: ClaimedNameRecord[];
  agents: AgentCompanyRecord[];
}
