/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as accounts from "../accounts.js";
import type * as alerts from "../alerts.js";
import type * as clerk from "../clerk.js";
import type * as crons from "../crons.js";
import type * as deletion from "../deletion.js";
import type * as guests from "../guests.js";
import type * as hosting from "../hosting.js";
import type * as http from "../http.js";
import type * as identities from "../identities.js";
import type * as joining from "../joining.js";
import type * as lib_apns from "../lib/apns.js";
import type * as lib_callers from "../lib/callers.js";
import type * as lib_config from "../lib/config.js";
import type * as lib_crypto from "../lib/crypto.js";
import type * as lib_errors from "../lib/errors.js";
import type * as lib_events from "../lib/events.js";
import type * as lib_joinCode from "../lib/joinCode.js";
import type * as lib_phase from "../lib/phase.js";
import type * as lib_storage from "../lib/storage.js";
import type * as lib_versions from "../lib/versions.js";
import type * as measures from "../measures.js";
import type * as pictures from "../pictures.js";
import type * as proofs from "../proofs.js";
import type * as push from "../push.js";
import type * as pushTokens from "../pushTokens.js";
import type * as reads from "../reads.js";
import type * as reports from "../reports.js";
import type * as rolls from "../rolls.js";
import type * as schedule from "../schedule.js";
import type * as storageQueue from "../storageQueue.js";
import type * as support from "../support.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  accounts: typeof accounts;
  alerts: typeof alerts;
  clerk: typeof clerk;
  crons: typeof crons;
  deletion: typeof deletion;
  guests: typeof guests;
  hosting: typeof hosting;
  http: typeof http;
  identities: typeof identities;
  joining: typeof joining;
  "lib/apns": typeof lib_apns;
  "lib/callers": typeof lib_callers;
  "lib/config": typeof lib_config;
  "lib/crypto": typeof lib_crypto;
  "lib/errors": typeof lib_errors;
  "lib/events": typeof lib_events;
  "lib/joinCode": typeof lib_joinCode;
  "lib/phase": typeof lib_phase;
  "lib/storage": typeof lib_storage;
  "lib/versions": typeof lib_versions;
  measures: typeof measures;
  pictures: typeof pictures;
  proofs: typeof proofs;
  push: typeof push;
  pushTokens: typeof pushTokens;
  reads: typeof reads;
  reports: typeof reports;
  rolls: typeof rolls;
  schedule: typeof schedule;
  storageQueue: typeof storageQueue;
  support: typeof support;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
