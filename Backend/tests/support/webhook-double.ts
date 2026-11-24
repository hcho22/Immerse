// A stand-in for the operator's support relay (convex/reports.ts): records each report it is sent, with its signature,
// and answers with the status a test chose.
import { createServer } from "node:http";

export type RelayedReport = { body: Record<string, unknown>; raw: string; signature: string | undefined };

export async function startSupportRelay() {
  const received: RelayedReport[] = [];
  let status = 200;
  const server = createServer((request, response) => {
    let raw = "";
    request.on("data", (chunk) => (raw += chunk));
    request.on("end", () => {
      received.push({ body: JSON.parse(raw), raw, signature: request.headers["x-immerse-signature"] as string | undefined });
      response.writeHead(status);
      response.end();
    });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("no address");
  const secret = "relay-secret-for-tests";
  process.env.SUPPORT_REPORT_WEBHOOK_URL = `http://127.0.0.1:${address.port}/reports`;
  process.env.SUPPORT_REPORT_WEBHOOK_SECRET = secret;
  return {
    received,
    secret,
    answerWith(next: number) {
      status = next;
    },
    close: async () => {
      delete process.env.SUPPORT_REPORT_WEBHOOK_URL;
      delete process.env.SUPPORT_REPORT_WEBHOOK_SECRET;
      await new Promise<void>((resolve) => server.close(() => resolve()));
    },
  };
}
