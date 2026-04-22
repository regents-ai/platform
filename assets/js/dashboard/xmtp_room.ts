import { animate, stagger } from "animejs";
import type { Hook } from "phoenix_live_view";

import { signDashboardWalletMessage } from "./islands";

type DashboardXmtpRoomElement = HTMLElement & {
  __xmtpSeenKeys?: Set<string>;
  __xmtpLastStatus?: string;
};

function animateStatus(el: HTMLElement | null, nextStatus: string, force = false) {
  if (!el) return;

  if (!force && el.textContent === nextStatus) return;

  el.textContent = nextStatus;

  animate(el, {
    opacity: [0.5, 1],
    translateY: [-4, 0],
    duration: 260,
    ease: "outQuad",
  });
}

function animateEntries(root: DashboardXmtpRoomElement, initial = false) {
  const seenKeys = root.__xmtpSeenKeys ?? new Set<string>();
  const feed = root.querySelector<HTMLElement>("[data-dashboard-xmtp-feed]");
  const entries = Array.from(root.querySelectorAll<HTMLElement>("[data-xmtp-entry]"));

  const newEntries = entries.filter((entry) => {
    const key = entry.dataset.messageKey || entry.id;

    if (seenKeys.has(key)) return false;
    seenKeys.add(key);
    return true;
  });

  root.__xmtpSeenKeys = seenKeys;

  const shouldAutoScroll = feed && (initial || (newEntries.length > 0 && isNearBottom(feed)));

  if (shouldAutoScroll) {
    requestAnimationFrame(() => {
      feed.scrollTop = feed.scrollHeight;
    });
  }

  if (!initial && newEntries.length > 0) {
    animate(newEntries, {
      opacity: [0, 1],
      translateY: [18, 0],
      scale: [0.98, 1],
      delay: stagger(70),
      duration: 380,
      ease: "outExpo",
    });
  }
}

function isNearBottom(el: HTMLElement, threshold = 72): boolean {
  return el.scrollHeight - el.scrollTop - el.clientHeight <= threshold;
}

export const DashboardXmtpRoomHook: Hook = {
  mounted() {
    const root = this.el as DashboardXmtpRoomElement;
    const status = root.querySelector<HTMLElement>("[data-dashboard-xmtp-status]");

    root.__xmtpLastStatus = status?.textContent ?? "";
    animateEntries(root, true);

    this.handleEvent("xmtp:sign-request", async (payload) => {
      const { request_id, signature_text, wallet_address } = payload as {
        request_id: string;
        signature_text: string;
        wallet_address?: string | null;
      };

      try {
        animateStatus(status, "Check your wallet to finish joining.", true);

        const signature = await signDashboardWalletMessage(
          String(signature_text ?? ""),
          typeof wallet_address === "string" ? wallet_address : null,
        );

        animateStatus(status, "Joining room...", true);

        this.pushEvent("xmtp_join_signature_signed", {
          request_id,
          signature,
        });
      } catch (error) {
        const message =
          error instanceof Error && error.message
            ? error.message
            : "We could not finish joining this room.";

        animateStatus(status, message, true);
        this.pushEvent("xmtp_join_signature_failed", { message });
      }
    });
  },

  updated() {
    const root = this.el as DashboardXmtpRoomElement;
    const status = root.querySelector<HTMLElement>("[data-dashboard-xmtp-status]");
    const nextStatus = status?.textContent ?? "";

    if (root.__xmtpLastStatus !== nextStatus) {
      root.__xmtpLastStatus = nextStatus;
      animateStatus(status, nextStatus, true);
    }

    animateEntries(root);
  },
};
