# liquid_glass_shader

Liquid glass for Flutter chrome: glass that refracts, frosts or tints the page behind it, and a tab bar made of that glass that behaves like the iOS 26 one.

## Glass

**Glass**:
Chrome that shows the page behind it, bent at the rim and lightly frosted, never content itself.
_Avoid_: acrylic, blur (a blur is one tier of glass)

**Style**:
The app-wide choice between clear and frosted glass.
_Avoid_: mode, variant

**Look**:
The full set of optics for one style: frost, tint, rim curve, bend, colour split, highlight, sheen and saturation.
_Avoid_: preset, appearance

**Rim**:
The band along the edge of glass where it curves, bends what is behind it and catches the light.

**Edge**:
The thin outer hairline that separates glass from a light page.
_Avoid_: border, outline

**Tier**:
How much work glass does on this device: refraction, blur or solid.
_Avoid_: quality level, mode

**Cap**:
The best tier glass may use right now; it only ever comes down during a session.
_Avoid_: limit, ceiling

**Guard**:
The watch over frame timing that lowers the cap when frames keep landing late.

**Shared backdrop**:
One copy of the screen behind, reused in a frame by every piece of glass that shares.

## Tab bar

**Tab bar**:
The row of tabs in a capsule of glass.
_Avoid_: nav bar, navigation bar, bottom bar

**Tab**:
One destination in the tab bar; passive content the bar draws and handles touch for.

**Slot**:
The equal share of the row's width that one tab sits in.

**Inset**:
The space between the glass's edge and the row of tabs.
_Avoid_: padding

**Hugging bar**:
A tab bar only as long as its tabs need, placed within the space it is given; the usual tab bar, as on iOS.
_Avoid_: compact bar, small bar

**Filling bar**:
A tab bar that stretches across the whole length it is given.
_Avoid_: full-width bar

**Vertical bar**:
A tab bar standing as a column at the side of the screen, as on the iPhone Duo's cover screen.
_Avoid_: rail, sidebar, side bar

**Stacked**:
The tab layout with the icon above the label, as on an iPhone held upright.

**Inline**:
The tab layout with the icon beside the label, or the label alone, as on iPad.

**Compact inline**:
The smallest tab layout, inline in a short bar, as on an iPhone held sideways.

**Separating fold**:
A hinge, or a fold that is partly closed, that divides the screen in two; no tab sits on one.
_Avoid_: crease, seam

**Lens**:
The capsule of glass that marks the selected tab.
_Avoid_: indicator, highlight, thumb

**Resting lens**:
The lens sitting in the bar under the selected tab, tinted.

**Lifted lens**:
The lens raised under a finger: larger than its slot, clear, and magnifying the tabs under it.

**Lens gap**:
The space between the resting lens and the edges of its slot.

**Jelly**:
The lens drawing out along its path with speed and wobbling round again when it stops.
_Avoid_: stretch effect, squash

**Catch-up**:
The lens closing the distance to a finger that pressed away from it.

**Rubber band**:
The growing resistance when the lens is pulled past the first or last tab.

**Tick**:
The feedback played each time the lens moves onto another tab.
_Avoid_: haptic, click

**Minimized**:
The state of a tab bar shrunk down to show only the current tab, as while a page scrolls down.
_Avoid_: collapsed

**Pill**:
The small glass shape a minimized tab bar shrinks into.
_Avoid_: using "pill" for the capsule shape of the bar or lens
