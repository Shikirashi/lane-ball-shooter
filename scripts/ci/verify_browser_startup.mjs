#!/usr/bin/env node
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawn } from "node:child_process";

const url = process.argv[2];
if (!url || !url.startsWith("https://")) {
  console.error("Usage: verify_browser_startup.mjs HTTPS_URL");
  process.exit(2);
}

const browser = process.env.CHROME_BIN || "google-chrome";
const profile = mkdtempSync(join(tmpdir(), "lane-ball-shooter-chrome-"));
const child = spawn(browser, [
  "--headless=new",
  "--no-sandbox",
  "--disable-dev-shm-usage",
  "--enable-unsafe-swiftshader",
  "--enable-webgl",
  "--ignore-gpu-blocklist",
  "--remote-debugging-pipe",
  "--window-size=1280,720",
  `--user-data-dir=${profile}`,
], { stdio: ["ignore", "ignore", "inherit", "pipe", "pipe"] });

let nextId = 1;
let buffer = Buffer.alloc(0);
const pending = new Map();

child.stdio[4].on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  let separator;
  while ((separator = buffer.indexOf(0)) >= 0) {
    const packet = buffer.subarray(0, separator).toString("utf8");
    buffer = buffer.subarray(separator + 1);
    if (!packet) continue;
    const message = JSON.parse(packet);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result);
    }
  }
});

function command(method, params = {}, sessionId = undefined) {
  const id = nextId++;
  const payload = { id, method, params };
  if (sessionId) payload.sessionId = sessionId;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    child.stdio[3].write(`${JSON.stringify(payload)}\0`);
  });
}

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

function waitForExit(milliseconds) {
  if (child.exitCode !== null || child.signalCode !== null) return Promise.resolve(true);
  return new Promise((resolve) => {
    const timer = setTimeout(() => {
      child.off("exit", onExit);
      resolve(false);
    }, milliseconds);
    const onExit = () => {
      clearTimeout(timer);
      resolve(true);
    };
    child.once("exit", onExit);
  });
}

async function stopBrowser() {
  if (await waitForExit(5000)) return;
  child.kill("SIGTERM");
  if (await waitForExit(5000)) return;
  child.kill("SIGKILL");
  await waitForExit(5000);
}

async function removeProfile() {
  for (let attempt = 1; attempt <= 8; attempt += 1) {
    try {
      rmSync(profile, { recursive: true, force: true, maxRetries: 2, retryDelay: 100 });
      return;
    } catch (error) {
      if (!["EBUSY", "ENOTEMPTY", "EPERM"].includes(error.code) || attempt === 8) {
        console.warn(`Unable to remove temporary Chrome profile ${profile}: ${error.message}`);
        return;
      }
      await delay(attempt * 100);
    }
  }
}

const timeout = setTimeout(() => {
  console.error("Browser startup verification timed out.");
  child.kill("SIGKILL");
  process.exitCode = 1;
}, 45000);

try {
  const { targetId } = await command("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await command("Target.attachToTarget", { targetId, flatten: true });
  await command("Page.enable", {}, sessionId);
  await command("Page.navigate", { url }, sessionId);
  await delay(15000);
  const expression = `JSON.stringify({
    secure: window.isSecureContext,
    title: document.title,
    canvasCount: document.querySelectorAll("canvas").length,
    canvasWidth: document.querySelector("canvas")?.width || 0,
    canvasHeight: document.querySelector("canvas")?.height || 0,
    loaderPresent: document.getElementById("status") !== null
  })`;
  const evaluation = await command("Runtime.evaluate", {
    expression,
    returnByValue: true,
  }, sessionId);
  const state = JSON.parse(evaluation.result.value);
  console.log(JSON.stringify(state));
  if (!state.secure || state.title !== "Lane Ball Shooter" || state.canvasCount !== 1 ||
      state.canvasWidth <= 0 || state.canvasHeight <= 0 || state.loaderPresent) {
    throw new Error("Godot did not reach a secure live canvas beyond its HTML loader.");
  }
  await command("Browser.close");
} catch (error) {
  console.error(error);
  child.kill("SIGKILL");
  process.exitCode = 1;
} finally {
  clearTimeout(timeout);
  await stopBrowser();
  await removeProfile();
}
