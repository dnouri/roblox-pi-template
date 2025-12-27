/**
 * Studio MCP Tools - Live interaction with Roblox Studio
 *
 * Provides two tools for pi-agent:
 * - studio_run_code: Execute Luau code in the running Studio session
 * - studio_insert_model: Insert models from Roblox marketplace
 *
 * Requires the MCP server (bin/rbx-studio-mcp --http-only) to be running
 * and the MCP plugin installed in Studio.
 */

import type { CustomToolFactory } from "@mariozechner/pi-coding-agent";
import { Text } from "@mariozechner/pi-tui";
import { Type } from "@sinclair/typebox";
import { randomUUID } from "node:crypto";

const MCP_PORT = 44755;
const MCP_URL = `http://127.0.0.1:${MCP_PORT}/proxy`;
const REQUEST_TIMEOUT_MS = 30000;

interface McpRequest {
	id: string;
	args: {
		RunCode?: { command: string };
		InsertModel?: { query: string };
	};
}

interface McpResponse {
	id: string;
	response: string;
}

interface RunCodeDetails {
	code: string;
	output?: string;
	error?: string;
}

interface InsertModelDetails {
	query: string;
	modelName?: string;
	error?: string;
}

async function isServerRunning(): Promise<boolean> {
	// Check if port is listening by attempting a TCP connection
	const net = await import("node:net");
	return new Promise((resolve) => {
		const socket = net.createConnection({ port: MCP_PORT, host: "127.0.0.1" });
		socket.setTimeout(1000);
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

async function sendMcpRequest(args: McpRequest["args"]): Promise<string> {
	const request: McpRequest = {
		id: randomUUID(),
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
		return data.response;
	} catch (error) {
		clearTimeout(timeout);
		if (error instanceof Error && error.name === "AbortError") {
			throw new Error("Request timed out. Is Studio connected to the MCP plugin?");
		}
		throw error;
	}
}

const factory: CustomToolFactory = (pi) => {
	async function ensureServerRunning(): Promise<void> {
		if (await isServerRunning()) {
			return;
		}

		// Try to start the server
		const result = await pi.exec("./scripts/start-mcp-server.sh", ["start"], { timeout: 10000 });
		if (result.code !== 0) {
			throw new Error(`Failed to start MCP server: ${result.stderr || result.stdout}`);
		}

		// Wait for server to be ready
		for (let i = 0; i < 10; i++) {
			if (await isServerRunning()) {
				return;
			}
			await new Promise((resolve) => setTimeout(resolve, 500));
		}

		throw new Error("MCP server started but not responding");
	}

	return [
		{
			name: "studio_run_code",
			label: "Studio Run Code",
			description:
				"For debugging and querying only. Use when user says 'live', 'in Studio', 'query', 'inspect', or 'check'. Do NOT use to create game objects - write .luau scripts in src/ instead.",
			parameters: Type.Object({
				code: Type.String({ description: "Luau code to execute in Studio" }),
			}),

			async execute(_toolCallId, params) {
				const { code } = params as { code: string };

				try {
					await ensureServerRunning();
					const output = await sendMcpRequest({ RunCode: { command: code } });

					return {
						content: [{ type: "text", text: output || "(no output)" }],
						details: { code, output } as RunCodeDetails,
					};
				} catch (error) {
					const errorMsg = error instanceof Error ? error.message : String(error);
					return {
						content: [{ type: "text", text: `Error: ${errorMsg}` }],
						details: { code, error: errorMsg } as RunCodeDetails,
					};
				}
			},

			renderCall(args, theme) {
				const code = (args as { code?: string }).code || "";
				const preview = code.length > 60 ? code.slice(0, 60) + "..." : code;
				return new Text(
					theme.fg("toolTitle", theme.bold("studio_run_code ")) + theme.fg("dim", preview),
					0,
					0
				);
			},

			renderResult(result, { expanded }, theme) {
				const details = result.details as RunCodeDetails | undefined;

				if (details?.error) {
					return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
				}

				const output = details?.output || "(no output)";
				const lines = output.split("\n");
				const preview = expanded ? output : lines.slice(0, 5).join("\n");
				const suffix = !expanded && lines.length > 5 ? `\n${theme.fg("dim", `... ${lines.length - 5} more lines`)}` : "";

				return new Text(theme.fg("success", "✓ ") + theme.fg("toolOutput", preview) + suffix, 0, 0);
			},
		},

		{
			name: "studio_insert_model",
			label: "Studio Insert Model",
			description:
				"Insert a model from Roblox marketplace into the current Studio session. Searches by query and inserts the first result.",
			parameters: Type.Object({
				query: Type.String({ description: "Search query for the marketplace model" }),
			}),

			async execute(_toolCallId, params) {
				const { query } = params as { query: string };

				try {
					await ensureServerRunning();
					const modelName = await sendMcpRequest({ InsertModel: { query } });

					return {
						content: [{ type: "text", text: `Inserted model: ${modelName}` }],
						details: { query, modelName } as InsertModelDetails,
					};
				} catch (error) {
					const errorMsg = error instanceof Error ? error.message : String(error);
					return {
						content: [{ type: "text", text: `Error: ${errorMsg}` }],
						details: { query, error: errorMsg } as InsertModelDetails,
					};
				}
			},

			renderCall(args, theme) {
				const query = (args as { query?: string }).query || "";
				return new Text(
					theme.fg("toolTitle", theme.bold("studio_insert_model ")) + theme.fg("accent", `"${query}"`),
					0,
					0
				);
			},

			renderResult(result, _options, theme) {
				const details = result.details as InsertModelDetails | undefined;

				if (details?.error) {
					return new Text(theme.fg("error", `Error: ${details.error}`), 0, 0);
				}

				return new Text(
					theme.fg("success", "✓ Inserted ") + theme.fg("accent", details?.modelName || "model"),
					0,
					0
				);
			},
		},
	];
};

export default factory;
