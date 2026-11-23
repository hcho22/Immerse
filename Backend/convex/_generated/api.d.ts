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
import type * as clerk from "../clerk.js";
import type * as deletion from "../deletion.js";
import type * as guests from "../guests.js";
import type * as http from "../http.js";
import type * as lib_apns from "../lib/apns.js";
import type * as lib_callers from "../lib/callers.js";
import type * as lib_crypto from "../lib/crypto.js";
import type * as lib_errors from "../lib/errors.js";
import type * as lib_storage from "../lib/storage.js";
import type * as pictures from "../pictures.js";
import type * as proofs from "../proofs.js";
import type * as push from "../push.js";
import type * as pushTokens from "../pushTokens.js";
import type * as reads from "../reads.js";
import type * as storageQueue from "../storageQueue.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  accounts: typeof accounts;
  clerk: typeof clerk;
  deletion: typeof deletion;
  guests: typeof guests;
  http: typeof http;
  "lib/apns": typeof lib_apns;
  "lib/callers": typeof lib_callers;
  "lib/crypto": typeof lib_crypto;
  "lib/errors": typeof lib_errors;
  "lib/storage": typeof lib_storage;
  pictures: typeof pictures;
  proofs: typeof proofs;
  push: typeof push;
  pushTokens: typeof pushTokens;
  reads: typeof reads;
  storageQueue: typeof storageQueue;
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
