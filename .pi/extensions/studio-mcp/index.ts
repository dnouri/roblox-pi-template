/**
 * Studio MCP Extension - Live interaction with Roblox Studio
 *
 * Provides studio_run_code tool to execute Luau code in the running Studio session.
 *
 * Requires the MCP server (bin/rbx-studio-mcp --http-only) to be running
 * and the MCP plugin installed in Studio.
 * 
 * CONTEXT SUPPORT:
 * - "any": Auto-detect (default) - uses server if playing, edit otherwise
 * - "edit": Edit mode - query static scene (available even during play)
 * - "server": Server DataModel - query live game state (only during play)
 * 
 * Note: Client context exists internally but is not exposed (no HTTP access).
 */

import { StringEnum } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { randomUUID } from "node:crypto";
import * as net from "node:net";

// Configuration
const MCP_PORT = 44755;
const MCP_URL = `http://127.0.0.1:${MCP_PORT}/proxy`;

// Timeouts (ms)
const REQUEST_TIMEOUT_MS = 30000;       // How long to wait for Studio response
const SOCKET_CHECK_TIMEOUT_MS = 1000;   // TCP connection check timeout
const SERVER_START_TIMEOUT_MS = 10000;  // How long to wait for server script
const SERVER_READY_RETRIES = 10;        // Retry count for server readiness
const SERVER_READY_INTERVAL_MS = 500;   // Delay between readiness checks

type Context = "edit" | "server" | "any";

interface McpRequest {
	id: string;
	context?: Context;
	args: {
		RunCode: { command: string };
	};
}

interface McpResponse {
	id: string;
	response: string;
	context?: string;
}

interface RunCodeDetails {
	code: string;
	context?: string;
	output?: string;
	error?: string;
}

async function isServerRunning(): Promise<boolean> {
	return new Promise((resolve) => {
		const socket = net.createConnection({ port: MCP_PORT, host: "127.0.0.1" });
		socket.setTimeout(SOCKET_CHECK_TIMEOUT_MS);
		socket.on("connect", () => {
			socket.destroy();
			resolve(true);
		});
		socket.on("error", () => resolve(false));
		socket.on("timeout", () => {
			socket.destroy();
			resolve(false);
		});
	});
}

async function sendMcpRequest(args: McpRequest["args"], context: Context = "any"): Promise<McpResponse> {
	const request: McpRequest = {
		id: randomUUID(),
		context,
		args,
	};

	const controller = new AbortController();
	const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

	try {
		const response = await fetch(MCP_URL, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify(request),
			signal: controller.signal,
		});

		clearTimeout(timeout);

		if (!response.ok) {
			throw new Error(`HTTP ${response.status}: ${response.statusText}`);
		}

		const data = (await response.json()) as McpResponse;
		return data;
	} catch (error) {
		clearTimeout(timeout);
		if (error instanceof Error && error.name === "AbortError") {
			throw new Error(
				"Request timed out. Studio may not be connected.\n" +
				"• Is Studio running with your project open?\n" +
				"• Check Studio Output for '[MCP Plugin] Connected'\n" +
				"• For server context: press Play first"
			);
		}
		throw error;
	}
}

export default function (pi: ExtensionAPI) {
	async function ensureServerRunning(): Promise<void> {
		if (await isServerRunning()) {
			return;
		}

		// Try to start the server
		const result = await pi.exec("./scripts/start-mcp-server.sh", ["start"], { timeout: SERVER_START_TIMEOUT_MS });
		if (result.code !== 0) {
			throw new Error(`Failed to start MCP server: ${result.stderr || result.stdout}`);
		}

		// Wait for server to be ready
		for (let i = 0; i < SERVER_READY_RETRIES; i++) {
			if (await isServerRunning()) {
				return;
			}
			await new Promise((resolve) => setTimeout(resolve, SERVER_READY_INTERVAL_MS));
		}

		throw new Error(
			"MCP server started but not responding.\n" +
			"• Check if bin/rbx-studio-mcp is running: ps aux | grep rbx-studio-mcp\n" +
			"• Try restarting: ./scripts/start-mcp-server.sh restart"
		);
	}

	pi.registerTool({
		name: "studio_run_code",
		label: "Studio Run Code",
		description:
			"Execute Luau code in Studio. Automatically targets whichever context is available (edit mode or server during play). Use 'context' parameter to target specific: 'edit', 'server', or 'any' (default).",
		parameters: Type.Object({
			code: Type.String({ description: "Luau code to execute in Studio" }),
			context: Type.Optional(StringEnum(["edit", "server", "any"] as const, { 
				description: "Target context: 'any' (default, auto-detect), 'edit', or 'server'" 
			})),
		}),

		async execute(_toolCallId, params, _onUpdate, _ctx, _signal) {
			const { code, context = "any" } = params as { code: string; context?: Context };

			try {
				await ensureServerRunning();
				const response = await sendMcpRequest({ RunCode: { command: code } }, context);
				const output = response.response || "(no output)";
				const respondedContext = response.context;

				return {
					content: [{ type: "text", text: respondedContext ? `[${respondedContext}] ${output}` : output }],
					details: { code, context: respondedContext, output } as RunCodeDetails,
				};
			} catch (error) {
				const errorMsg = error instanceof Error ? error.message : String(error);
				return {
					content: [{ type: "text", text: `Error: ${errorMsg}` }],
					details: { code, context, error: errorMsg } as RunCodeDetails,
				};
			}
		},

		renderCall(args, theme) {
			const { code, context } = args as { code?: string; context?: string };
			const preview = (code || "").length > 50 ? (code || "").slice(0, 50) + "..." : (code || "");
			const ctxLabel = context && context !== "any" ? `[${context}] ` : "";
			return new Text(
				theme.fg("toolTitle", theme.bold("studio_run_code ")) + theme.fg("accent", ctxLabel) + theme.fg("dim", preview),
				0,
				0
			);
		},

		renderResult(result, { expanded }, theme) {
			const details = result.details as RunCodeDetails | undefined;

			if (details?.error) {
				return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
			}

			const ctxPrefix = details?.context ? `[${details.context}] ` : "";
			const output = details?.output || "(no output)";
			const lines = output.split("\n");
			const preview = expanded ? output : lines.slice(0, 5).join("\n");
			const suffix = !expanded && lines.length > 5 ? `\n${theme.fg("dim", `... ${lines.length - 5} more lines`)}` : "";

			return new Text(theme.fg("success", "✓ ") + theme.fg("accent", ctxPrefix) + theme.fg("toolOutput", preview) + suffix, 0, 0);
		},
	});
}
