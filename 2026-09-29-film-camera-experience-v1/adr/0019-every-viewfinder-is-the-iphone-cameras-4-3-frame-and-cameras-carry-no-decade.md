# Every Viewfinder is the iPhone Camera's 4:3 photo frame, under a one-line header, and the Cameras carry no decade

After using the app on his iPhone, the captain asked on 2026-10-26: "Viewfinder screen size same is native iOS camera app".
Under ADR 0017 each Camera's viewfinder was the largest box of its own shape that the room above the shutter bar left after a header of two or three lines and the Camera's controls, so it differed from Camera to Camera and was narrower than the screen on a short iPhone.

**One Viewfinder area on every Camera.**
He chose "A, change the Camera's name to Super 8, 16mm, Instant, Disposable, 6x6, and the count should be just a number."
Every Camera's Viewfinder area is the iPhone Camera app's 4:3 photo frame: the full width of the screen, edge to edge, in the same place on every Camera and every iPhone, and the same in every hold.
Each Camera's shape sits inside that area as the iPhone Camera app's square mode does: the Instant's and the 6×6's squares fill its width, the movie Cameras' 4:3 fills it exactly, and the Disposable's taller 3:2 picture fills its height, with bars at the sides.
The header becomes one line in the top bar beside Done: the Camera's short name and the count as just a number, such as "27" for a photo Film and "3:20" for a movie Film, while VoiceOver still says the whole count.
The 6×6's Zoom Steps and sliders, the focus switch and the movie Cameras' Zoom Steps float over the bottom of the Viewfinder area or move into the shutter bar, so no control changes where the Viewfinder area is.
The rest of ADR 0017 stands: the screen never turns, only its words and icons do, and the live picture fills the Camera's shape in every hold.
Screenshots on the smallest and largest supported iPhones go to the captain for approval before this ships.

**The Cameras are named without a decade.**
Asked whether the short names belonged on the shooting screen only, as firstmate recommended, or everywhere, he chose everywhere: "B, we don't need the year of the camera".
The Cameras are named Disposable, Instant, 6×6, Super 8 and 16mm on every screen, and each catalog description carries the era and the look.
Product text keeps "6×6" with the multiplication sign, spoken "6 by 6", as before.
A Film already loaded keeps its stored Camera package unchanged and is shown with the new name.
The Format References (ADR 0015) are unchanged and stay internal.

The alternatives considered were keeping the viewfinder sized to the room under a taller header, as ADR 0017 had it, and short names on the shooting screen only, with the full names everywhere else.
The accepted costs are that the controls now sit over the bottom of the live picture or in the shutter bar instead of beside it, that the Disposable's picture has bars at its sides, as a square has in the iPhone Camera app, and that the era no longer shows in a Camera's name, only in its description.

Decided on 2026-10-26.
