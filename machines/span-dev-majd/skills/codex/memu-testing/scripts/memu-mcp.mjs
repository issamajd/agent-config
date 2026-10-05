#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { createInterface } from "node:readline";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// The app under test is chosen by the caller (Invoke-CodexMEmuTest.ps1 sets these).
const projectRoot = resolve(process.env.MEMU_PROJECT_ROOT ?? process.cwd());
const serial = process.env.MEMU_ADB_SERIAL ?? "127.0.0.1:21503";
const packageName = process.env.MEMU_PACKAGE_NAME;
if (!packageName) {
  console.error("MEMU_PACKAGE_NAME is not set: pass -Package to Invoke-CodexMEmuTest.ps1.");
  process.exit(2);
}
const projectPath = process.env.MEMU_PROJECT_PATH
  ? resolve(projectRoot, process.env.MEMU_PROJECT_PATH)
  : null;
const adbCommand = process.env.ADB ?? (process.platform === "win32" ? "adb.exe" : "adb");

function run(command, args, { binary = false, timeout = 30_000, allowFailure = false } = {}) {
  const result = spawnSync(command, args.map(String), {
    cwd: projectRoot,
    encoding: binary ? null : "utf8",
    maxBuffer: 32 * 1024 * 1024,
    timeout,
    windowsHide: true,
  });
  if (result.error) throw new Error(`${command} could not run: ${result.error.message}`);
  if (result.status !== 0 && !allowFailure) {
    const stdout = binary ? result.stdout?.toString("utf8") : result.stdout;
    const stderr = binary ? result.stderr?.toString("utf8") : result.stderr;
    const details = [stdout, stderr]
      .map((value) => (value ?? "").trim())
      .filter(Boolean)
      .join("\n");
    throw new Error(`${command} ${args.join(" ")} failed${details ? `:\n${details}` : "."}`);
  }
  return binary ? result.stdout : (result.stdout ?? "").trim();
}

function adb(args, options) {
  return run(adbCommand, ["-s", serial, ...args], options);
}

function sleep(milliseconds) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function ensureConnected() {
  const devices = run(adbCommand, ["devices"]);
  const ready = devices.split(/\r?\n/).some((line) => line.startsWith(`${serial}\tdevice`));
  if (!ready && serial.includes(":")) run(adbCommand, ["connect", serial]);
  if (adb(["get-state"]) !== "device") throw new Error(`MEmu ADB target ${serial} is not ready.`);
}

function currentFocus() {
  return adb(["shell", "dumpsys", "window", "windows"])
    .split(/\r?\n/)
    .find((line) => line.includes("mCurrentFocus="))
    ?.trim() ?? "unknown";
}

function isInstalled() {
  return adb(["shell", "pm", "path", packageName], { allowFailure: true }).startsWith("package:");
}

function statusText() {
  ensureConnected();
  const model = adb(["shell", "getprop", "ro.product.model"]);
  const android = adb(["shell", "getprop", "ro.build.version.release"]);
  const size = adb(["shell", "wm", "size"]);
  return [
    `ADB serial: ${serial}`,
    `Device: ${model}`,
    `Android: ${android}`,
    `Screen: ${size.replace(/^Physical size:\s*/, "")}`,
    `Package: ${packageName} (${isInstalled() ? "installed" : "not installed"})`,
    `Focus: ${currentFocus()}`,
  ].join("\n");
}

// App dialogs are focused windows titled by the dialog (e.g. "Window{5760fd u0 New Operation Confirmation}"),
// so fall back to the owning package recorded in that window's dumpsys block.
function focusedWindowOwnedByPackage(focus) {
  const id = focus.match(/Window\{(\w+) /)?.[1];
  if (!id)
    return false;
  const block = adb(["shell", "dumpsys", "window", "windows"])
    .split(/\r?\n\s*Window #/)
    .find((section) => section.includes(`Window{${id} `) && !section.includes("mCurrentFocus="));
  return (block ?? "").includes(` package=${packageName} `);
}

function assertFocused() {
  const focus = currentFocus();
  if (!focus.includes(`${packageName}/`) && !focusedWindowOwnedByPackage(focus)) {
    throw new Error(
      `Input refused because focus left ${packageName}. Current focus: ${focus}. ` +
      "Call launch_app or ask the user before expanding scope.",
    );
  }
}

function launchApp() {
  ensureConnected();
  if (!isInstalled()) throw new Error(`${packageName} is not installed. Call deploy_app first.`);
  adb(["shell", "monkey", "-p", packageName, "-c", "android.intent.category.LAUNCHER", "1"]);
  for (let attempt = 0; attempt < 12; attempt += 1) {
    if (currentFocus().includes(`${packageName}/`)) return `Launched ${packageName}.\n${currentFocus()}`;
    sleep(500);
  }
  throw new Error(`Launched ${packageName}, but it did not receive focus.`);
}

function deployApp() {
  if (!projectPath) throw new Error("No project to deploy: pass -Project to Invoke-CodexMEmuTest.ps1, or install the app yourself and call launch_app.");
  ensureConnected();
  const output = run("dotnet", [
    "build", projectPath, "-f", "net8.0-android", "-t:Run",
    "-p:DisableLegacyStrongName=true", `-p:AdbTarget=-s ${serial}`,
  ], { timeout: 300_000 });
  return `${output}\n\n${statusText()}`;
}

function captureScreenshot() {
  ensureConnected();
  const png = adb(["exec-out", "screencap", "-p"], { binary: true });
  if (!png || png.length < 24 || png.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a") {
    throw new Error("MEmu did not return a valid PNG screenshot.");
  }
  return { png, width: png.readUInt32BE(16), height: png.readUInt32BE(20) };
}

function integer(value, name, minimum = 0, maximum = 10_000) {
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer from ${minimum} to ${maximum}.`);
  }
  return value;
}

function shellSafeText(value) {
  if (typeof value !== "string" || value.length > 500) {
    throw new Error("text must be a string of at most 500 characters.");
  }
  if (!/^[\x20-\x7E]*$/.test(value)) throw new Error("type_text supports printable ASCII only.");
  return value
    .replace(/%/g, "\\%")
    .replace(/ /g, "%s")
    .replace(/([&|;<>()$`'"\\!*?#~])/g, "\\$1");
}

const keycodes = new Map([
  ["ENTER", "KEYCODE_ENTER"], ["RETURN", "KEYCODE_ENTER"],
  ["ESC", "KEYCODE_ESCAPE"], ["ESCAPE", "KEYCODE_ESCAPE"],
  ["TAB", "KEYCODE_TAB"], ["SPACE", "KEYCODE_SPACE"],
  ["BACKSPACE", "KEYCODE_DEL"], ["DELETE", "KEYCODE_FORWARD_DEL"],
  ["UP", "KEYCODE_DPAD_UP"], ["DOWN", "KEYCODE_DPAD_DOWN"],
  ["LEFT", "KEYCODE_DPAD_LEFT"], ["RIGHT", "KEYCODE_DPAD_RIGHT"],
  ["BACK", "KEYCODE_BACK"],
]);

function keycode(value) {
  const normalized = String(value ?? "").toUpperCase();
  if (keycodes.has(normalized)) return keycodes.get(normalized);
  if (/^[A-Z0-9]$/.test(normalized)) return `KEYCODE_${normalized}`;
  throw new Error(`Unsupported Android key: ${value}`);
}

const objectSchema = (properties = {}, required = []) => ({
  type: "object", properties, required, additionalProperties: false,
});
const coordinate = { type: "integer", minimum: 0, maximum: 10_000 };

const tools = [
  {
    name: "status",
    description: "Check the fixed MEmu target, app installation, screen size, and focused activity.",
    inputSchema: objectSchema(),
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "deploy_app",
    description: "Build, install, and launch the configured MAUI app on MEmu.",
    inputSchema: objectSchema(),
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "launch_app",
    description: "Bring the installed app to the foreground.",
    inputSchema: objectSchema(),
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "restart_app",
    description: "Force-stop and relaunch the app without clearing app data.",
    inputSchema: objectSchema(),
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "screenshot",
    description: "Capture the complete MEmu screen as an original-resolution PNG.",
    inputSchema: objectSchema(),
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  {
    name: "tap",
    description: "Tap one coordinate inside the focused app.",
    inputSchema: objectSchema({ x: coordinate, y: coordinate }, ["x", "y"]),
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
  },
  {
    name: "swipe",
    description: "Swipe between two coordinates inside the focused app.",
    inputSchema: objectSchema({
      start_x: coordinate, start_y: coordinate, end_x: coordinate, end_y: coordinate,
      duration_ms: { type: "integer", minimum: 50, maximum: 5000, default: 300 },
    }, ["start_x", "start_y", "end_x", "end_y"]),
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
  },
  {
    name: "type_text",
    description: "Type printable ASCII text into the focused control.",
    inputSchema: objectSchema({ text: { type: "string", maxLength: 500 } }, ["text"]),
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
  },
  {
    name: "key",
    description: "Send a safe Android key such as ENTER, BACK, TAB, an arrow, letter, or digit.",
    inputSchema: objectSchema({ key: { type: "string", minLength: 1, maxLength: 20 } }, ["key"]),
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
  },
  {
    name: "recent_logs",
    description: "Read recent logcat entries for the running app process.",
    inputSchema: objectSchema({ lines: { type: "integer", minimum: 20, maximum: 1000, default: 250 } }),
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
];

function textResult(text) {
  return { content: [{ type: "text", text }] };
}

function callTool(name, args = {}) {
  switch (name) {
    case "status": return textResult(statusText());
    case "deploy_app": return textResult(deployApp());
    case "launch_app": return textResult(launchApp());
    case "restart_app":
      ensureConnected();
      adb(["shell", "am", "force-stop", packageName]);
      return textResult(launchApp());
    case "screenshot": {
      const shot = captureScreenshot();
      return {
        content: [
          { type: "text", text: `${shot.width}x${shot.height}\n${currentFocus()}` },
          { type: "image", data: shot.png.toString("base64"), mimeType: "image/png" },
        ],
      };
    }
    case "tap":
      assertFocused();
      adb(["shell", "input", "tap", integer(args.x, "x"), integer(args.y, "y")]);
      return textResult(`Tapped (${args.x}, ${args.y}).`);
    case "swipe": {
      assertFocused();
      const values = [
        integer(args.start_x, "start_x"), integer(args.start_y, "start_y"),
        integer(args.end_x, "end_x"), integer(args.end_y, "end_y"),
        integer(args.duration_ms ?? 300, "duration_ms", 50, 5000),
      ];
      adb(["shell", "input", "swipe", ...values]);
      return textResult(`Swiped (${values[0]}, ${values[1]}) to (${values[2]}, ${values[3]}).`);
    }
    case "type_text":
      assertFocused();
      adb(["shell", "input", "text", shellSafeText(args.text)]);
      return textResult(`Typed ${args.text.length} character(s).`);
    case "key":
      assertFocused();
      adb(["shell", "input", "keyevent", keycode(args.key)]);
      return textResult(`Sent Android key ${args.key}.`);
    case "recent_logs": {
      ensureConnected();
      const pid = adb(["shell", "pidof", packageName], { allowFailure: true }).split(/\s+/)[0];
      if (!pid) throw new Error(`${packageName} is not currently running.`);
      const lines = integer(args.lines ?? 250, "lines", 20, 1000);
      return textResult(adb(["shell", "logcat", "-d", `--pid=${pid}`, "-t", lines]));
    }
    default: throw new Error(`Unknown tool: ${name}`);
  }
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function handle(message) {
  if (!message || message.jsonrpc !== "2.0") return;
  if (message.method === "notifications/initialized" || message.method?.startsWith("notifications/")) return;
  try {
    let result;
    switch (message.method) {
      case "initialize":
        result = {
          protocolVersion: message.params?.protocolVersion ?? "2025-06-18",
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: "memu", version: "1.0.0" },
          instructions: `Use these bounded tools to visually test ${packageName} on MEmu.`,
        };
        break;
      case "ping": result = {}; break;
      case "tools/list": result = { tools }; break;
      case "tools/call": result = callTool(message.params?.name, message.params?.arguments ?? {}); break;
      default: throw Object.assign(new Error(`Method not found: ${message.method}`), { code: -32601 });
    }
    if (message.id !== undefined) send({ jsonrpc: "2.0", id: message.id, result });
  } catch (error) {
    if (message.method === "tools/call" && message.id !== undefined) {
      send({
        jsonrpc: "2.0", id: message.id,
        result: { content: [{ type: "text", text: error.message }], isError: true },
      });
    } else if (message.id !== undefined) {
      send({
        jsonrpc: "2.0", id: message.id,
        error: { code: error.code ?? -32603, message: error.message },
      });
    }
  }
}

if (process.argv.includes("--self-test")) {
  try {
    const shot = captureScreenshot();
    console.log(statusText());
    console.log(`Screenshot: valid PNG (${shot.width}x${shot.height}, ${shot.png.length} bytes)`);
  } catch (error) {
    console.error(`Self-test failed: ${error.message}`);
    process.exitCode = 1;
  }
} else {
  const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
  input.on("line", (line) => {
    if (!line.trim()) return;
    try { handle(JSON.parse(line)); }
    catch (error) { send({ jsonrpc: "2.0", id: null, error: { code: -32700, message: error.message } }); }
  });
}
