# Local StoreKit Test Data

`LocalSubscriptions.storekit` is bundled only in the test target. Its tiny
synthetic prices are test inputs, not proposed or selected live pricing. No
Apple portal configuration, credentials, real purchases or public distribution
are involved. The production app has no product IDs configured.

Tests instantiate Apple's SKTestSession from this file and exercise actual
StoreKit product lookup, purchase, pending approval, cached entitlement reads,
restore, expiration, transaction updates and errors. These do not prove live
StoreKit storefront behavior, device offline behavior or DEC-02 policy acceptance.
