// The join page's Worker in Cloudflare's own runtime, served locally: workerd, through Miniflare, running the Worker of
// Backend/worker bundled as `wrangler deploy` bundles it, with the bindings wrangler.example.jsonc names. It asks the
// local Convex backend's HTTP routes what it may show, as the deployed Worker asks the deployment's. Nothing here
// reaches Cloudflare.
import { join, resolve } from "node:path";
import { build } from "esbuild";
import { Miniflare } from "miniflare";

const workerRoot = resolve(import.meta.dirname, "../../worker");

export type JoinPage = { url: string; stop: () => Promise<void> };

export async function startJoinPage(options: {
  convexSiteUrl: string;
  gatewaySecret: string;
  // Link openings allowed a minute from one address.
  limit?: number;
  vars?: Record<string, string>;
}): Promise<JoinPage> {
  const bundle = await build({
    entryPoints: [join(workerRoot, "src/index.ts")],
    bundle: true,
    format: "esm",
    target: "es2022",
    logLevel: "silent",
    write: false,
  });
  const worker = new Miniflare({
    modules: [{ type: "ESModule", path: "index.js", contents: bundle.outputFiles[0]!.text }],
    compatibilityDate: "2026-07-01",
    host: "127.0.0.1",
    port: 0,
    bindings: {
      CONVEX_SITE_URL: options.convexSiteUrl,
      WEB_GATEWAY_SECRET: options.gatewaySecret,
      APPLE_TEAM_ID: "TEAM123456",
      APP_BUNDLE_ID: "com.immerse.FilmJournal",
      APP_CLIP_BUNDLE_ID: "com.immerse.FilmJournal.Clip",
      APP_STORE_ID: "1234567890",
      SUPPORT_ADDRESS: "support@immerse.test",
      ...options.vars,
    },
    ratelimits: { JOIN_LIMITER: { namespace_id: "1001", simple: { limit: options.limit ?? 1000, period: 60 } } },
  });
  const url = (await worker.ready).toString().replace(/\/+$/, "");
  return {
    url,
    stop: () => worker.dispose(),
  };
}
