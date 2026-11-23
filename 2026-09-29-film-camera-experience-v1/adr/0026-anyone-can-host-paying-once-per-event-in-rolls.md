# Anyone can host, paying once per event in Rolls

Under ADR 0005 only a subscriber could create a Group Film, and the Host's subscription supplied the first load with no free event capacity.
On 2026-11-22 the captain answered: "anyone can host, paying once per event by exposure count. free size for users with subscription."

**Anyone can host, and pays by exposure count, in Rolls.**
Hosting needs an Account (ADR 0028) but no subscription.
An event is paid for once, by exposure count, sold in Rolls: one Roll per guest.
The Host can add Rolls while the event is open.

**A Roll is used only when a guest takes it.**
Rolls set aside for an event come from the Host's balance, but a Roll is used only when a guest takes it at joining, and Rolls unclaimed at the event's end return to the Host's balance for a future event.
This answers the complaint of one of Once's reviewers, that a host pays upfront for photos guests never take.

**A free event for everyone, and more for subscribers.**
Everyone gets a very small free event, about 3 Rolls, and subscribers get a clearly larger free size.

**Rolls are bought through Apple's in-app purchase into the Host's signed-in balance.**
A subscriber's free Rolls are credited to that balance once the server has confirmed the subscription with Apple, and one subscription feeds one Account.
The v1 subscription itself stays account-free for personal Films.

**Numbers are left open.**
The structure is fixed; prices, pack sizes and free amounts are left to the pricing decision still open for the v1 subscription (DEC-02).

**What this supersedes.**
ADR 0005 is superseded in full.
ADR 0006's statement that an expired subscription blocks Group Film hosting and new Subscriber Load contributions no longer applies, because hosting needs no subscription and there are no Subscriber Loads; its rule that expiry never locks existing Films stands.

The alternatives considered were the parked subscription-only hosting, pricing by guest count as Once does, and a subscription tier for hosting.
The accepted costs are that a Host must sign in to hold a balance, that the server must verify purchases and subscriptions with Apple, and that a guest who takes a Roll and shoots little still uses it, as a disposable handed out is used.

Decided by the captain on 2026-11-22 (v2 PRD, version 1.0).
