// Who is opening the link, as far as a browser says (v2 PRD V2-FR-18): an iPhone that can shoot, an iPhone on an iOS
// before 26, or anything else (an Android phone, a computer, an iPad). Shooting needs an iPhone on iOS 26.
//
// The User-Agent is the only evidence a page has, and it is weak on purpose: Safari has frozen parts of it, and apps
// that show pages in their own browser leave the Safari version out. So only a clear answer is treated as one. An
// iPhone whose iOS cannot be told is shown the way to join together with the iOS 26 requirement, never refused.
export type Device = "iphone" | "iphoneUnknown" | "iphoneTooOld" | "android" | "other";

export const MINIMUM_IOS = 26;

export function deviceFor(userAgent: string | null): Device {
  const agent = userAgent ?? "";
  if (/Android/i.test(agent)) return "android";
  if (!/\biPhone\b/.test(agent)) return "other";
  const safari = /\bVersion\/(\d+)/.exec(agent);
  const system = /\biPhone OS (\d+)[_.]/.exec(agent);
  const safariVersion = safari ? Number(safari[1]) : undefined;
  const systemVersion = system ? Number(system[1]) : undefined;
  if ((safariVersion ?? 0) >= MINIMUM_IOS || (systemVersion ?? 0) >= MINIMUM_IOS) return "iphone";
  // Safari's version follows iOS's, so a Safari before 26 is an iOS before 26.
  if (safariVersion !== undefined) return "iphoneTooOld";
  // No Safari version: an app's own browser. Its system version is trusted only where it is clearly old, since iOS 26
  // reports a frozen iOS 18 there.
  if (systemVersion !== undefined && systemVersion < 18) return "iphoneTooOld";
  return "iphoneUnknown";
}

export function isIPhone(device: Device): boolean {
  return device === "iphone" || device === "iphoneUnknown" || device === "iphoneTooOld";
}
