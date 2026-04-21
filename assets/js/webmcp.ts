type WebMCPTool = {
  name: string;
  description: string;
  inputSchema: {
    type: "object";
    properties: {
      openInNewTab: {
        type: "boolean";
        description: string;
      };
    };
  };
  execute: (input?: { openInNewTab?: boolean }) => { ok: true; url: string };
};

type ModelContextLike = {
  provideContext: (context: { tools: WebMCPTool[] }) => unknown;
};

function createOpenTool(
  targetWindow: Window & typeof globalThis,
  name: string,
  description: string,
  url: string,
): WebMCPTool {
  return {
    name,
    description,
    inputSchema: {
      type: "object",
      properties: {
        openInNewTab: {
          type: "boolean",
          description: "Open the destination in a new tab instead of replacing the current page.",
        },
      },
    },
    execute(input) {
      if (input?.openInNewTab) {
        targetWindow.open(url, "_blank", "noopener,noreferrer");
      } else {
        targetWindow.location.assign(url);
      }

      return { ok: true, url };
    },
  };
}

export function registerWebMCP(targetWindow: Window & typeof globalThis): void {
  const navigatorWithModelContext = targetWindow.navigator as Navigator & {
    modelContext?: ModelContextLike;
  };

  if (targetWindow.__regentsWebMcpRegistered || !navigatorWithModelContext.modelContext?.provideContext) {
    return;
  }

  const tools = [
    createOpenTool(
      targetWindow,
      "open_regents_app",
      "Open the guided Regent setup flow in the website.",
      new URL("/app", targetWindow.location.origin).toString(),
    ),
    createOpenTool(
      targetWindow,
      "open_regents_cli",
      "Open the Regents CLI guide.",
      new URL("/cli", targetWindow.location.origin).toString(),
    ),
    createOpenTool(
      targetWindow,
      "open_techtree",
      "Open the Techtree product page.",
      new URL("/techtree", targetWindow.location.origin).toString(),
    ),
    createOpenTool(
      targetWindow,
      "open_autolaunch",
      "Open the Autolaunch product page.",
      new URL("/autolaunch", targetWindow.location.origin).toString(),
    ),
    createOpenTool(
      targetWindow,
      "open_regents_docs",
      "Open the Regent docs page.",
      new URL("/docs", targetWindow.location.origin).toString(),
    ),
  ];

  navigatorWithModelContext.modelContext.provideContext({ tools });
  targetWindow.__regentsWebMcpRegistered = true;
}

declare global {
  interface Window {
    __regentsWebMcpRegistered?: boolean;
  }
}
