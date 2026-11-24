// The join page's words and markup (v2 PRD V2-FR-15, V2-FR-18, V2-FR-20, V2-FR-47, V2-FR-48).
//
// One page per link, which always says something plain: who can join and how, why this person cannot join here and
// what they can do instead, or the album while the Host shares it on the web. It offers no camera, no upload and no
// file picker (V2-FR-20), loads nothing from another site, and previews in Messages with the event's title only, never
// a picture (V2-FR-15): it carries no preview image of any kind.
import { type Device, isIPhone, MINIMUM_IOS } from "./device";

export type AlbumEntry =
  | { number: number; removed: true }
  | {
      number: number;
      removed: false;
      pictureId: string;
      shooterName: string;
      captureTime: number;
      contentType: string;
      size: number;
      crc32: number | null;
    };

export type EventDescription = {
  title: string;
  hostName: string | null;
  hostLeft: boolean;
  camera: "disposable" | "6x6" | "instant";
  filmStock: "color" | "blackAndWhite" | null;
  exposuresPerRoll: number;
  opensAt: number;
  endsAt: number;
  revealsAt: number;
  albumEndsAt: number;
  albumNotice: "none" | "month" | "week";
};

export type LivePage = {
  status: "scheduled" | "open" | "paused" | "full" | "ended" | "revealed";
  event: EventDescription;
  album: AlbumEntry[] | null;
};

export type Page = { status: "unknown" } | { status: "unavailable" } | { status: "replaced" } | LivePage;

// What the page knows of the app: set where the Worker is deployed, never in the repository.
export type AppLinks = {
  // The App Store id of Immerse, once it has one; the App Clip's bundle identifier.
  appStoreId?: string;
  appClipBundleId?: string;
  supportAddress?: string;
};

export function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

const MONTHS = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
  "December",
];

// A time for a page with scripts off: in UTC, and said so. With scripts on, the page shows it in the reader's own time
// zone (V2-FR-12).
function utcWords(ms: number): string {
  const date = new Date(ms);
  const minutes = String(date.getUTCMinutes()).padStart(2, "0");
  const hours = String(date.getUTCHours()).padStart(2, "0");
  return `${date.getUTCDate()} ${MONTHS[date.getUTCMonth()]} ${date.getUTCFullYear()} at ${hours}:${minutes} UTC`;
}

function time(ms: number, kind: "moment" | "day" = "moment"): string {
  const words = kind === "day" ? utcWords(ms).replace(/ at .*$/, "") : utcWords(ms);
  return `<time datetime="${new Date(ms).toISOString()}" data-local="${kind}">${words}</time>`;
}

const CAMERAS = { disposable: "Disposable", "6x6": "6×6", instant: "Instant" } as const;
const STOCKS = { color: "Color", blackAndWhite: "Black and white" } as const;

const STYLE = `
:root{color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;background:#000;color:#fff;font:17px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;-webkit-text-size-adjust:100%}
main{max-width:44rem;margin:0 auto;padding:2.5rem 1.25rem 3rem}
h1{font-size:1.9rem;line-height:1.15;margin:0 0 .4rem;font-weight:700;overflow-wrap:anywhere}
h2{font-size:1.15rem;margin:2rem 0 .6rem;font-weight:650}
p{margin:.5rem 0}
.brand{letter-spacing:.14em;text-transform:uppercase;font-size:.8rem;color:#b8b8b8;margin:0 0 1.6rem}
.quiet{color:#c9c9c9}
.small{font-size:.9rem;color:#b8b8b8}
.note{border:1px solid #4a4a4a;border-radius:1rem;padding:1rem 1.1rem;margin:1.4rem 0;background:#0f0f0f}
.note p:first-child{margin-top:0}.note p:last-child{margin-bottom:0}
.lead{font-size:1.15rem;font-weight:600}
a{color:#fff}
a.action{display:inline-block;background:#f3ead9;color:#000;font-weight:650;text-decoration:none;padding:.85rem 1.4rem;border-radius:999px;margin:.6rem .6rem 0 0;min-height:44px}
a.plain{display:inline-block;border:1px solid #777;color:#fff;font-weight:600;text-decoration:none;padding:.8rem 1.3rem;border-radius:999px;margin:.6rem .6rem 0 0;min-height:44px}
a:focus-visible{outline:3px solid #fff;outline-offset:3px}
ol.album{list-style:none;margin:1rem 0 0;padding:0;display:grid;grid-template-columns:repeat(auto-fill,minmax(7.5rem,1fr));gap:6px}
ol.album li{position:relative;aspect-ratio:1;background:#141414;border-radius:3px;overflow:hidden}
ol.album a{display:block;width:100%;height:100%}
ol.album img{width:100%;height:100%;object-fit:cover;display:block}
ol.album .number{position:absolute;left:.35rem;bottom:.25rem;font-size:.8rem;font-variant-numeric:tabular-nums;text-shadow:0 0 4px #000,0 0 2px #000;pointer-events:none}
ol.album li.gap{background:none;border:1px solid #3d3d3d;display:flex;align-items:center;justify-content:center;color:#b8b8b8;font-size:.9rem}
figure{margin:1.2rem 0}
figure img{max-width:100%;max-height:78vh;display:block;margin:0 auto;border-radius:3px}
dl{margin:1rem 0;display:grid;grid-template-columns:auto 1fr;gap:.25rem 1rem}
dt{color:#b8b8b8}dd{margin:0}
footer{margin-top:3rem;border-top:1px solid #2c2c2c;padding-top:1rem}
`;

// Shows each time in the reader's own time zone. The page reads the same without it.
const SCRIPT = `
for (const node of document.querySelectorAll("time[data-local]")) {
  const date = new Date(node.getAttribute("datetime"));
  if (isNaN(date)) continue;
  const day = { weekday: "long", day: "numeric", month: "long", year: "numeric" };
  node.textContent = node.dataset.local === "day"
    ? date.toLocaleDateString(undefined, day)
    : date.toLocaleString(undefined, { ...day, hour: "numeric", minute: "2-digit" });
}
`;

export type Rendered = { html: string; nonce: string };

function document(options: {
  title: string;
  head?: string;
  body: string;
  links: AppLinks;
  nonce: string;
}): string {
  const support = options.links.supportAddress;
  const footer = support
    ? `<footer><p class="small">Immerse's support: <a href="mailto:${escapeHtml(support)}">${escapeHtml(support)}</a></p></footer>`
    : "";
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="no-referrer">
<meta name="color-scheme" content="dark">
<title>${escapeHtml(options.title)}</title>
<meta property="og:title" content="${escapeHtml(options.title)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Immerse">
${options.head ?? ""}<style nonce="${options.nonce}">${STYLE}</style>
</head>
<body>
<main>
<p class="brand">Immerse</p>
${options.body}
${footer}
</main>
<script nonce="${options.nonce}">${SCRIPT}</script>
</body>
</html>
`;
}

// The Smart App Banner and App Clip card (Apple: "Supporting invocations from your website and the Messages app"),
// on an iPhone and only where the page has something the app could open.
function appBanner(links: AppLinks, device: Device): string {
  if (!isIPhone(device) || !links.appStoreId) return "";
  const clip = links.appClipBundleId ? `, app-clip-bundle-id=${links.appClipBundleId}, app-clip-display=card` : "";
  return `<meta name="apple-itunes-app" content="app-id=${escapeHtml(links.appStoreId)}${escapeHtml(clip)}">\n`;
}

function appStoreLink(links: AppLinks, words: string): string {
  if (!links.appStoreId) return "";
  return `<a class="action" href="https://apps.apple.com/app/id${escapeHtml(links.appStoreId)}">${words}</a>`;
}

function described(event: EventDescription): string {
  const host = event.hostLeft ? "The Host has left Immerse" : `Hosted by ${escapeHtml(event.hostName ?? "the Host")}`;
  const details = [CAMERAS[event.camera], `${event.exposuresPerRoll} exposures a Roll`];
  if (event.filmStock) details.push(STOCKS[event.filmStock]);
  return `<h1>${escapeHtml(event.title)}</h1>
<p class="quiet">${host}</p>
<p class="small">${details.join(" · ")}</p>`;
}

// What someone who cannot shoot here is told (V2-FR-18's first two rows), or nothing for an iPhone that can.
function deviceNote(device: Device, revealed: boolean): string {
  switch (device) {
    case "iphone":
      return "";
    case "iphoneUnknown":
      return `<p class="small">Shooting needs iOS ${MINIMUM_IOS} or later.</p>`;
    case "iphoneTooOld":
      return `<div class="note"><p>Shooting needs iOS ${MINIMUM_IOS} or later. Update this iPhone to join.</p></div>`;
    default:
      return revealed
        ? `<p class="small">Shooting needs an iPhone on iOS ${MINIMUM_IOS}.</p>`
        : `<div class="note"><p>Shooting needs an iPhone on iOS ${MINIMUM_IOS}. The pictures will be on this page after the reveal if the Host shares them.</p></div>`;
  }
}

// How an iPhone joins: the mini-app with nothing to install, or the full app where the mini-app cannot open, such as
// a child's Apple Account or one with Ask to Buy, where Apple does not offer App Clips.
function joinRoute(links: AppLinks, device: Device): string {
  if (device === "iphoneTooOld" || !isIPhone(device)) return "";
  return `<div class="note">
<p class="lead">Join on this iPhone</p>
<p>Tap <strong>Open</strong> on the Immerse card to join with nothing to install: give a name, take a Roll and start shooting.</p>
<p class="small">No card? It does not show in a private tab, inside another app's browser, or for an Apple Account that cannot use App Clips, such as a child's account or one with Ask to Buy. Install Immerse, then open this link again.</p>
${appStoreLink(links, "Get Immerse")}
</div>`;
}

// For someone who already joined: the same link opens the album in the app or the mini-app (V2-FR-15, V2-FR-71).
function memberRoute(links: AppLinks, device: Device, words: string): string {
  if (device === "iphoneTooOld" || !isIPhone(device)) return "";
  return `<p class="small">${words}</p>${appStoreLink(links, "Get Immerse")}`;
}

function albumNotice(event: EventDescription): string {
  if (event.albumNotice === "none") return "";
  return `<div class="note"><p>This album ends on ${time(event.albumEndsAt, "day")}. Save the pictures you want to keep.</p></div>`;
}

export type AlbumPart = { number: number; from: number; to: number; bytes: number };

function megabytes(bytes: number): string {
  const mb = bytes / 1_000_000;
  return mb >= 10 ? `${Math.round(mb)} MB` : `${Math.max(0.1, Math.round(mb * 10) / 10)} MB`;
}

function album(code: string, entries: AlbumEntry[], parts: AlbumPart[]): string {
  const stored = entries.filter((entry) => !entry.removed);
  if (stored.length === 0) {
    return `<p class="quiet">The album has no pictures yet. Pictures still on their way appear here when they arrive.</p>`;
  }
  const width = String(entries.length).length < 2 ? 2 : String(entries.length).length;
  const pad = (n: number) => String(n).padStart(width, "0");
  const items = entries
    .map((entry) =>
      entry.removed
        ? `<li class="gap" aria-label="Picture ${entry.number}, removed">${pad(entry.number)}</li>`
        : `<li><a href="/j/${code}/v/${entry.pictureId}"><img src="/j/${code}/p/${entry.pictureId}/view" alt="Picture ${entry.number}" loading="lazy" decoding="async"><span class="number" aria-hidden="true">${pad(entry.number)}</span></a></li>`,
    )
    .join("\n");
  const downloads =
    parts.length === 1
      ? `<a class="plain" href="/j/${code}/album.zip">Download the album (${megabytes(parts[0]!.bytes)})</a>`
      : parts
          .map(
            (part) =>
              `<a class="plain" href="/j/${code}/album.zip?part=${part.number}">Pictures ${part.from} to ${part.to} (${megabytes(part.bytes)})</a>`,
          )
          .join("\n");
  return `<h2>The album</h2>
<p class="small">${stored.length} ${stored.length === 1 ? "picture" : "pictures"}, in the order they were taken. Open one to see who took it and to save it.</p>
<ol class="album">
${items}
</ol>
${parts.length === 0 ? "" : `<h2>${parts.length === 1 ? "Save them all" : "Save them all, in parts"}</h2>
${downloads}
`}<p class="small">A saved picture is your own copy. Removing it from the album later cannot recall it.</p>`;
}

export function joinPage(options: {
  code: string;
  page: Page;
  device: Device;
  links: AppLinks;
  parts: AlbumPart[];
  nonce: string;
}): { html: string; status: number } {
  const { page, device, links, nonce } = options;
  if (page.status === "unknown" || page.status === "unavailable") {
    return { status: 404, html: messagePage("This event is no longer available.", links, nonce) };
  }
  if (page.status === "replaced") {
    return { status: 410, html: messagePage("This link no longer works. Ask the Host for the new one.", links, nonce) };
  }
  const event = page.event;
  const head = appBanner(links, device);
  const parts: string[] = [described(event)];
  switch (page.status) {
    case "scheduled":
      parts.push(`<div class="note"><p class="lead">This event opens ${time(event.opensAt)}.</p><p>Come back then.</p></div>`);
      parts.push(`<p class="small">Shooting ends ${time(event.endsAt)}. The album reveals ${time(event.revealsAt)}.</p>`);
      parts.push(deviceNote(device, false));
      break;
    case "paused":
      parts.push(`<div class="note"><p class="lead">Joining is paused for now.</p></div>`);
      parts.push(memberRoute(links, device, "Already joined? Open this link in Immerse on your iPhone to keep shooting."));
      parts.push(deviceNote(device, false));
      break;
    case "full":
      parts.push(`<div class="note"><p class="lead">Every Roll has been taken.</p><p>The Host can add more.</p></div>`);
      parts.push(memberRoute(links, device, "Already joined? Open this link in Immerse on your iPhone to keep shooting."));
      parts.push(deviceNote(device, false));
      break;
    case "open":
      parts.push(`<p>Shooting ends ${time(event.endsAt)}. The album reveals ${time(event.revealsAt)}.</p>`);
      parts.push(`<p class="small">Every picture stays sealed until the reveal. After it, everyone who joined sees every picture.</p>`);
      parts.push(joinRoute(links, device));
      parts.push(deviceNote(device, false));
      break;
    case "ended":
      parts.push(`<div class="note"><p class="lead">Shooting has ended.</p><p>The album reveals ${time(event.revealsAt)}.</p></div>`);
      parts.push(memberRoute(links, device, "If you joined, open this link in Immerse on your iPhone after the reveal to see the album."));
      parts.push(deviceNote(device, false));
      break;
    case "revealed":
      if (page.album === null) {
        parts.push(`<div class="note"><p class="lead">This event's pictures are not shared on the web.</p></div>`);
        parts.push(memberRoute(links, device, "If you joined, open this link in Immerse on your iPhone to see the album."));
        parts.push(deviceNote(device, true));
      } else {
        parts.push(albumNotice(event));
        parts.push(album(options.code, page.album, options.parts));
        parts.push(deviceNote(device, true));
        parts.push(`<p class="small">This page is for looking and saving. To report a picture, write to Immerse's support.</p>`);
      }
      break;
  }
  return { status: 200, html: document({ title: event.title, head, body: parts.filter(Boolean).join("\n"), links, nonce }) };
}

// One picture with its details (V2-FR-45, V2-FR-47): the Guest Name, when it was taken and the Camera, and a way to
// save it. The name is here and nowhere else: not on the album's grid, not in the saved file.
export function picturePage(options: {
  code: string;
  event: EventDescription;
  entry: Extract<AlbumEntry, { removed: false }>;
  links: AppLinks;
  nonce: string;
}): string {
  const { code, event, entry, links, nonce } = options;
  const body = `<h1>Picture ${entry.number}</h1>
<p class="quiet">${escapeHtml(event.title)}</p>
<figure><img src="/j/${code}/p/${entry.pictureId}/view" alt="Picture ${entry.number}"></figure>
<dl>
<dt>Taken by</dt><dd>${escapeHtml(entry.shooterName)}</dd>
<dt>Taken</dt><dd>${time(entry.captureTime)}</dd>
<dt>Camera</dt><dd>${CAMERAS[event.camera]}</dd>
</dl>
<a class="action" href="/j/${code}/p/${entry.pictureId}/full?download=1" download>Save this picture (${megabytes(entry.size)})</a>
<a class="plain" href="/j/${code}">Back to the album</a>
<p class="small">A saved picture is your own copy. Removing it from the album later cannot recall it.</p>`;
  return document({ title: event.title, body, links, nonce });
}

export function messagePage(message: string, links: AppLinks, nonce: string, title = "Immerse"): string {
  return document({ title, body: `<div class="note"><p class="lead">${escapeHtml(message)}</p></div>`, links, nonce });
}
