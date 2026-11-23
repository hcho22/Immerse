// A stand-in for Clerk's Backend API: records each request and answers with the status a test chose.
import { createServer, type IncomingMessage } from "node:http";

export type ClerkRequest = { method: string; path: string; authorization: string | undefined };

export async function startClerkDouble() {
  const requests: ClerkRequest[] = [];
  let status = 200;
  const server = createServer((request: IncomingMessage, response) => {
    requests.push({ method: request.method ?? "", path: request.url ?? "", authorization: request.headers.authorization });
    response.writeHead(status, { "content-type": "application/json" });
    const id = (request.url ?? "").split("/").pop();
    response.end(status === 200 ? JSON.stringify({ id, object: "user", deleted: true }) : JSON.stringify({ errors: [] }));
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("no address");
  const secretKey = "sk_test_stand_in";
  process.env.CLERK_API_URL = `http://127.0.0.1:${address.port}`;
  process.env.CLERK_SECRET_KEY = secretKey;
  return {
    requests,
    secretKey,
    answerWith(next: number) {
      status = next;
    },
    close: () => new Promise<void>((resolve) => server.close(() => resolve())),
  };
}
