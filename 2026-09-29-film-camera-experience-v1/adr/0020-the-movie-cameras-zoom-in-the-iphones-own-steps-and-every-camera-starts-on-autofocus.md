# The movie Cameras zoom in the iPhone's own steps, and every Camera starts on autofocus

After using the app on his iPhone, the captain asked two things about lenses on 2026-10-26: "Super 8/ 16mm - change focal length to native iOS lens" and "implement autofocus option to all camera".
Under ADR 0017 only the 6×6's rear camera offered Zoom Steps, and the Super 8 and the 16mm recorded on the rear wide lens at 1x.
Focus was set for each Camera with no choice: the Disposable and the Super 8 held one fixed lens position, the 6×6 was focused by hand, and the Instant and the 16mm used the phone's continuous autofocus.

**The Super 8 and the 16mm offer the iPhone's own Zoom Steps.**
He chose "A": the movie Cameras' rear camera offers the same Zoom Steps as the 6×6's, under the same rules.
There is one step for each lens the iPhone has, and a sensor-crop step only where the phone's camera reports one; there is nothing between them and no pinch or digital zoom, and the front camera keeps its single lens.
A step is taken only between Recorded Clips, never while one records.
The alternative was to keep one lens and match the iPhone Camera app's 1x framing.

**A focus switch that starts on Auto.**
He chose "A".
The Disposable and the Super 8 get a focus switch, "Auto / Fixed", and the 6×6 gets "Auto / Manual", with its Focus slider shown only in Manual.
Every new Film starts on Auto, and each Film remembers its setting.
Auto is the phone's continuous autofocus plus tap-to-focus on the Viewfinder, as in the iPhone's Camera app, on all five Cameras.
The Instant and the 16mm have no switch, since they have nothing to switch to, and gain tap-to-focus.
The switch's place on the shooting screen is shown to the captain for approval before it is final.
The switch is a capture control, not part of the Camera package locked at Load Film, so a Film loaded before this change gets it too and starts on Auto; this is firstmate's stated default.

**What this supersedes.**
ADR 0017's "Zoom is on the 6×6 only ...; the front camera and every other Camera keep their single lens" now reads: the 6×6, the Super 8 and the 16mm offer Zoom Steps on the rear camera, and the Disposable, the Instant and every front camera keep their single lens.
ADR 0017's "the Super 8's fixed focus ... stand" now reads: the Super 8's fixed focus is the Fixed side of its switch.
The 6×6's focus and exposure controls, its square framing at every step and the note "Manual focus unavailable on this lens" stand as ADR 0017 has them.

The accepted costs are that the Super 8, whose Format Reference had one fixed-focus lens and one focal length, now focuses and zooms as a phone does unless set to Fixed, and that the Disposable's fixed focus, the character the catalog promised, is now a choice its person can leave off.

Decided on 2026-10-26.
