// A counting proxy in front of the R2 stand-in, for measuring an event's storage operations (open check OC-2). The
// deployment signs addresses for the proxy's own address, and the proxy passes every request through unchanged, the
// Host header included, so each signature still verifies. It counts what Cloudflare bills: Class A operations
// (uploads), Class B operations (reads) and the bytes each moves. Deletions are free on R2 and counted apart.
import { createServer, request as forward } from "node:http";

export type StorageCounts = {
  classA: number;
  classB: number;
  deletes: number;
  bytesUploaded: number;
  bytesDownloaded: number;
};

export async function startCountingProxy(target: string) {
  const counts: StorageCounts = { classA: 0, classB: 0, deletes: 0, bytesUploaded: 0, bytesDownloaded: 0 };
  const targetUrl = new URL(target);
  const server = createServer((incoming, outgoing) => {
    const method = incoming.method ?? "GET";
    const upstream = forward(
      { host: targetUrl.hostname, port: targetUrl.port, method, path: incoming.url, headers: incoming.headers },
      (response) => {
        let downloaded = 0;
        response.on("data", (chunk: Buffer) => (downloaded += chunk.length));
        response.on("end", () => {
          const ok = (response.statusCode ?? 500) < 300;
          if (method === "GET" && ok) counts.bytesDownloaded += downloaded;
        });
        outgoing.writeHead(response.statusCode ?? 502, response.headers);
        response.pipe(outgoing);
      },
    );
    let uploaded = 0;
    incoming.on("data", (chunk: Buffer) => (uploaded += chunk.length));
    incoming.on("end", () => {
      if (method === "PUT" || method === "POST") {
        counts.classA += 1;
        counts.bytesUploaded += uploaded;
      } else if (method === "GET" || method === "HEAD") {
        counts.classB += 1;
      } else if (method === "DELETE") {
        counts.deletes += 1;
      }
    });
    incoming.pipe(upstream);
    upstream.on("error", () => {
      outgoing.writeHead(502);
      outgoing.end();
    });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("no address");
  return {
    endpoint: `http://127.0.0.1:${address.port}`,
    counts,
    reset() {
      Object.assign(counts, { classA: 0, classB: 0, deletes: 0, bytesUploaded: 0, bytesDownloaded: 0 });
    },
    close: () => new Promise<void>((resolve) => server.close(() => resolve())),
  };
}
