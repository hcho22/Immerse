# Local StoreKit Test Data

`LocalSubscriptions.storekit` is bundled only in the test target. Its tiny
synthetic prices are test inputs, not proposed or selected live pricing. No
Apple portal configuration, credentials, real purchases or public distribution
are involved. The production app has no product IDs configured.

Tests instantiate Apple's SKTestSession from this file and exercise actual
StoreKit product lookup, purchase, pending approval, cached entitlement reads,
restore, expiration, transaction updates and errors. These do not prove live
StoreKit storefront behavior, device offline behavior or DEC-02 policy acceptance.

`LocalRolls.storekit` holds two synthetic consumable Roll packs for v2's
`RollShopStoreKitTests`. Their identifiers, Roll counts and prices are test
inputs only, not the pricing decision (OC-5): the app reads what is on sale from
the server and each price from the App Store, and no pack is configured for
production. Like the subscription file, it runs only where Apple's local StoreKit
session activates (CI's iOS 26.2 billing simulator).
