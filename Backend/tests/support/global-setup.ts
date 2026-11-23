// Starts the local S3-compatible stand-in for R2 once for the whole test run: MinIO, on a free port, with fresh
// random credentials and a private bucket. MinIO checks SigV4 presigned addresses, their expiry, their signed
// headers (the content type) and `x-amz-checksum-sha256` as S3 does. It is not R2: Backend/README.md lists what only
// the real bucket can show. Install it with `brew install minio`, or set MINIO_BINARY to its path.
import { spawn, type ChildProcess } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { createServer } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { AwsClient } from "aws4fetch";
import type { TestProject } from "vitest/node";

declare module "vitest" {
  export interface ProvidedContext {
    storage: { endpoint: string; bucket: string; accessKeyId: string; secretAccessKey: string; region: string };
  }
}

function freePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close(() => (typeof address === "object" && address ? resolve(address.port) : reject(new Error("no port"))));
    });
  });
}

let minio: ChildProcess | undefined;
let dataDirectory: string | undefined;

export async function setup(project: TestProject) {
  const binary = process.env.MINIO_BINARY || "minio";
  const port = await freePort();
  const consolePort = await freePort();
  const accessKeyId = `test${randomBytes(8).toString("hex")}`;
  const secretAccessKey = randomBytes(24).toString("hex");
  dataDirectory = mkdtempSync(join(tmpdir(), "immerse-r2-"));
  minio = spawn(
    binary,
    ["server", dataDirectory, "--address", `127.0.0.1:${port}`, "--console-address", `127.0.0.1:${consolePort}`, "--quiet"],
    { env: { ...process.env, MINIO_ROOT_USER: accessKeyId, MINIO_ROOT_PASSWORD: secretAccessKey, MINIO_BROWSER: "off" }, stdio: "ignore" },
  );
  const failedToStart = new Promise<never>((_, reject) => {
    minio!.once("error", (error) =>
      reject(new Error(`The R2 stand-in could not start (${error.message}). Install MinIO with \`brew install minio\` or set MINIO_BINARY.`)),
    );
  });
  const endpoint = `http://127.0.0.1:${port}`;
  const ready = (async () => {
    for (let attempt = 0; attempt < 200; attempt += 1) {
      try {
        if ((await fetch(`${endpoint}/minio/health/live`)).ok) return;
      } catch {
        // Not listening yet.
      }
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    throw new Error("The R2 stand-in did not become ready in 20 seconds");
  })();
  await Promise.race([ready, failedToStart]);
  const bucket = "immerse-pictures";
  const region = "us-east-1";
  const client = new AwsClient({ accessKeyId, secretAccessKey, service: "s3", region });
  const created = await client.fetch(`${endpoint}/${bucket}`, { method: "PUT" });
  if (!created.ok) throw new Error(`Could not create the test bucket: HTTP ${created.status}`);
  project.provide("storage", { endpoint, bucket, accessKeyId, secretAccessKey, region });
}

export async function teardown() {
  if (minio && minio.exitCode === null) {
    const exited = new Promise((resolve) => minio!.once("exit", resolve));
    minio.kill("SIGTERM");
    await exited;
  }
  if (dataDirectory) rmSync(dataDirectory, { recursive: true, force: true });
}
