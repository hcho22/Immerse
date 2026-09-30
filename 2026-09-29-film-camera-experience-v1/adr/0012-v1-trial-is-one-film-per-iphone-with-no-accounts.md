# V1 Trial is one Film per iPhone, held on the device, with no app Accounts

The v1 Trial is one free Trial Film per iPhone, remembered on the phone in the Keychain, which normally survives deleting and reinstalling the app.
v1 therefore has no app Accounts, no sign-in, no server and no Account deletion flow.
Capture, Development, Darkroom, storage and export happen on the phone, and the subscription is bought, checked and restored through StoreKit and the user's Apple ID.

Moving Group Films to v2 left the Trial as the only use of an Account, because paid personal use already needed none.
Keeping an Account, a server reservation and an Account deletion flow only to stop a second free Film would have made a personal, on-phone app depend on a service.
The accepted cost is that someone with several iPhones gets several free Films, which costs only a possible sale because Films never leave the phone.
The Trial record stays bound to the physical iPhone and does not come back through a device-backup restore, so the Trial counts once per physical iPhone.
The Keychain behavior is to be confirmed on iOS 26 by an early device check before Trial work is built.

This reverses the domain model's Account-scoped Trial: the Account term, Trial eligibility tied to an Account across devices and reinstalls, Trial Activation as an online server reservation, Cancel Unused Trial, and Delete Account with Deletion Pending no longer apply to v1.
Accounts return in v2 when Groups need them, and the retired rules are preserved for v2 in the PRD (section 8.13) and the tracker's Deferred to v2 section.
Starting the Trial never needs connectivity.
After a backup is restored onto a new phone, a Trial Film with captures keeps capturing and a started Trial Film with no captures stays usable.
Restoring an older backup can bring back media discarded after it; that is accepted and disclosed in the privacy copy, with no removal log.

Decided by the captain on 2026-09-30 (PRD version 1.2).
