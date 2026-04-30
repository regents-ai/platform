import { animate } from "animejs";
import { isAddress } from "viem";

import type { DashboardConfig } from "./types";

export class HttpRequestError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = "HttpRequestError";
    this.status = status;
  }
}

export function parseConfig(raw: string | null | undefined): DashboardConfig | null {
  if (!raw) return null;

  try {
    return JSON.parse(raw) as DashboardConfig;
  } catch {
    return null;
  }
}

export function privyDebugEnabled(): boolean {
  if (typeof window === "undefined") return false;

  const params = new URLSearchParams(window.location.search);
  return (
    params.get("debug_privy") === "1" ||
    window.localStorage.getItem("debug:privy") === "1"
  );
}

export function normalizeWalletAddress(
  value: string | null | undefined,
): `0x${string}` | null {
  if (!value) return null;

  const trimmed = value.trim();
  if (!trimmed || !isAddress(trimmed)) return null;
  return trimmed as `0x${string}`;
}

export function redactWalletForDebug(
  value: string | null | undefined,
): string | null {
  const address = normalizeWalletAddress(value);
  if (!address) return null;
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function privyDebugLog(
  level: "info" | "warn" | "error",
  event: string,
  details: Record<string, unknown> = {},
) {
  if (!privyDebugEnabled()) return;

  const prefix = `[privy-debug] ${event}`;

  if (level === "error") {
    console.error(prefix, details);
    return;
  }

  if (level === "warn") {
    console.warn(prefix, details);
    return;
  }

  console.info(prefix, details);
}

export function debugHttpError(error: unknown): Record<string, unknown> {
  if (error instanceof HttpRequestError) {
    return {
      name: error.name,
      message: error.message,
      status: error.status,
    };
  }

  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
    };
  }

  return {
    message: String(error),
  };
}

export function abbreviateWalletAddress(value: string | null | undefined): string {
  const address = normalizeWalletAddress(value);
  if (!address) return "No wallet connected";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function prefersReducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

export function setNoticeState(
  el: HTMLElement,
  message: string,
  tone: "error" | "info" | "success",
) {
  el.classList.remove("hidden");
  el.textContent = message;

  const toneClass =
    tone === "error"
      ? "text-[color:#a6574f]"
      : tone === "success"
        ? "text-[color:var(--foreground)]"
        : "text-[color:var(--muted-foreground)]";

  const baseClass =
    el.dataset.noticeStyle === "compact"
      ? "text-sm leading-5"
      : "mt-4 text-sm leading-6";

  el.className = `${baseClass} ${toneClass}`;

  if (prefersReducedMotion()) return;

  animate(el, {
    opacity: [0, 1],
    translateY: [8, 0],
    duration: 240,
    ease: "outExpo",
  });
}

export function readRequiredValue(
  root: HTMLElement,
  selector: string,
  message: string,
) {
  const el = root.querySelector<HTMLInputElement>(selector);
  const value = el?.value?.trim();
  if (!value) throw new Error(message);
  return value;
}

export function requiredAddress(
  value: string | null | undefined,
  message: string,
): `0x${string}` {
  const trimmed = value?.trim();
  if (!trimmed || !isAddress(trimmed)) throw new Error(message);
  return trimmed as `0x${string}`;
}

export function requiredBigInt(value: string | null | undefined, message: string) {
  const trimmed = value?.trim();
  if (!trimmed) throw new Error(message);

  try {
    return BigInt(trimmed);
  } catch {
    throw new Error(message);
  }
}

export async function fetchJson<T>(input: string, init?: RequestInit): Promise<T> {
  const csrfToken = getCsrfToken();
  const method = (init?.method ?? "GET").toUpperCase();
  const shouldSendCsrfToken =
    csrfToken &&
    ["POST", "PUT", "PATCH", "DELETE"].includes(method) &&
    !hasHeader(init?.headers, "x-csrf-token");

  const response = await fetch(input, {
    ...init,
    headers: {
      accept: "application/json",
      ...(shouldSendCsrfToken ? { "x-csrf-token": csrfToken } : {}),
      ...(init?.headers ?? {}),
    },
  });

  const text = await response.text();
  const payload = tryParseJson(text);

  if (!response.ok) {
    const parsedPayload = payload as {
      error?: {
        message?: unknown;
      };
      statusMessage?: unknown;
      message?: unknown;
    } | null;

    const message =
      (parsedPayload &&
        ((typeof parsedPayload.error?.message === "string" &&
          parsedPayload.error.message) ||
          (typeof parsedPayload.statusMessage === "string" &&
          parsedPayload.statusMessage) ||
          (typeof parsedPayload.message === "string" &&
            parsedPayload.message))) ||
      text ||
      `Request failed (${response.status})`;

    privyDebugLog("warn", "fetch-json:request-failed", {
      input,
      method,
      status: response.status,
      message,
    });
    throw new HttpRequestError(message, response.status);
  }

  return (payload ?? {}) as T;
}

function getCsrfToken(): string | null {
  const token = document
    .querySelector("meta[name='csrf-token']")
    ?.getAttribute("content")
    ?.trim();

  return token ? token : null;
}

function hasHeader(headers: HeadersInit | undefined, name: string): boolean {
  if (!headers) return false;

  const normalizedName = name.toLowerCase();

  if (headers instanceof Headers) {
    return headers.has(normalizedName);
  }

  if (Array.isArray(headers)) {
    return headers.some(
      ([headerName]) => headerName.toLowerCase() === normalizedName,
    );
  }

  return Object.keys(headers).some(
    (headerName) => headerName.toLowerCase() === normalizedName,
  );
}

function tryParseJson(value: string): unknown {
  if (!value) return null;

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

export function getErrorMessage(error: unknown, fallback: string) {
  if (error instanceof Error && error.message) return error.message;
  if (error && typeof error === "object" && "message" in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === "string" && message) return message;
  }
  return fallback;
}

export function getPrivyDisplayName(privyUser: unknown): string | null {
  if (!privyUser || typeof privyUser !== "object") return null;

  if (
    "email" in privyUser &&
    privyUser.email &&
    typeof privyUser.email === "object" &&
    "address" in privyUser.email &&
    typeof privyUser.email.address === "string" &&
    privyUser.email.address.trim()
  ) {
    return privyUser.email.address.trim();
  }

  if (
    "twitter" in privyUser &&
    privyUser.twitter &&
    typeof privyUser.twitter === "object" &&
    "username" in privyUser.twitter &&
    typeof privyUser.twitter.username === "string" &&
    privyUser.twitter.username.trim()
  ) {
    return privyUser.twitter.username.trim();
  }

  return null;
}

export function createMintMessage(
  address: string,
  fqdn: string,
  chainId: number,
  timestamp: number,
) {
  return [
    "Regent Basenames Mint",
    `Address: ${address.toLowerCase()}`,
    `Name: ${fqdn.toLowerCase()}`,
    `ChainId: ${chainId}`,
    `Timestamp: ${timestamp}`,
  ].join("\n");
}

export function formatRegentRounded2(amount: bigint) {
  const denom = 10n ** 18n;
  const scaled = amount * 100n;
  const cents = (scaled + denom / 2n) / denom;
  const whole = cents / 100n;
  const fraction = cents % 100n;
  return `${whole.toLocaleString()}.${fraction.toString().padStart(2, "0")}`;
}
