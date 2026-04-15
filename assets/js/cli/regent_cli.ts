import {
  executePlatformCommand,
  parsePlatformCommand,
  platformUsageLines,
  type PlatformCommand,
} from "./platform_cli.ts";
import {
  exportSummaryPayload,
  parseShaderCommand,
  shaderListPayload,
  shaderUsageLines,
  type ShaderExportCommand,
  type ShaderListCommand,
} from "./shader_cli.ts";
import { exportShaderImage } from "./shader_export.ts";

export interface HelpCommand {
  kind: "help";
}

export type RegentCommand = ShaderListCommand | ShaderExportCommand | PlatformCommand | HelpCommand;

export function usageText() {
  return [...shaderUsageLines(), ...platformUsageLines()].join("\n");
}

export function parseRegentCommand(argv: readonly string[], cwd: string): RegentCommand {
  const args = [...argv];

  if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
    return { kind: "help" };
  }

  const [surface, command, ...rest] = args;
  const fullUsageText = usageText();

  if (surface === "shader") {
    return parseShaderCommand(command, rest, cwd, fullUsageText);
  }

  if (surface === "platform") {
    return parsePlatformCommand(command, rest, cwd, fullUsageText);
  }

  throw new Error(`Unknown command surface "${surface}".\n${fullUsageText}`);
}

export async function executeRegentCommand(command: RegentCommand) {
  if (command.kind === "shader-list") {
    return shaderListPayload(command);
  }

  if (command.kind === "shader-export") {
    const result = await exportShaderImage(command);
    return exportSummaryPayload(result);
  }

  if (command.kind === "help") {
    return { ok: true, command: "regent --help", usage: usageText() };
  }

  return executePlatformCommand(command);
}
