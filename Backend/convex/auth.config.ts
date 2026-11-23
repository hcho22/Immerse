// Clerk sign-in linked to Convex (V2-FR-01, section 9.2). Convex verifies each Clerk session token against the
// Clerk instance's issuer (its Frontend API URL) and requires the "convex" audience, which Clerk's Convex
// integration sets on session tokens. The issuer is deployment configuration, never committed: set
// CLERK_JWT_ISSUER_DOMAIN on the deployment (Backend/SETUP.md), or the local stand-in's address in tests.
import type { AuthConfig } from "convex/server";

export default {
  providers: [
    {
      domain: process.env.CLERK_JWT_ISSUER_DOMAIN!,
      applicationID: "convex",
    },
  ],
} satisfies AuthConfig;
