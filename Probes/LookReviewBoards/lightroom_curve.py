#!/usr/bin/env python3
"""Turns Lightroom Basic-panel tone values into a point curve for FilmLook's ToneCurve.

The captain writes some look notes as Lightroom slider values. Adobe does not publish the sliders' math, so this is a
stated approximation of their global effect on display tones (0 to 255), not Lightroom itself: Highlights and Shadows
are locally adaptive in Lightroom and are treated here as smooth curve regions.

  Blacks      moves the black end by 0.4 level per unit, fading out by tone 96
  Shadows     moves the tones around 64 by 0.32 level per unit
  Highlights  moves the tones around 192 by 0.34 level per unit, less at the white end
  Whites      moves the white end by 0.45 level per unit, fading in from tone 160
  Dehaze      below zero adds haze: lifts black by 0.35 level per unit and eases contrast toward mid-gray
  --black-node raises the curve's bottom-left node to that percent of the scale, as a tone-curve edit does
  --then       a point curve applied after the Basic values, as "in,out in,out ..." (the Tone Curve panel)

Clarity, Texture and saturation are not tone-curve edits; FilmLook sets them through Lens.diffusion (clarity below zero,
about its amount over 200), Lens.softness and ColorEmulsion.saturation.

Usage: lightroom_curve.py --highlights -54 --shadows -12 --whites -50 --blacks 10 --dehaze -10 [--then "0,0 30,25 ..."]
Prints ToneCurve's `points`, `black` and `white` for FilmLook.swift.
"""

import argparse
import math


def basic(x, args):
    """One display tone (0 to 255) through the Basic values."""
    blacks = 0.4 * args.blacks * max(0.0, 1 - x / 96) ** 2
    shadows = 0.32 * args.shadows * math.exp(-(((x - 64) / 48) ** 2))
    highlights = 0.34 * args.highlights * math.exp(-(((x - 192) / 56) ** 2))
    whites = 0.45 * args.whites * max(0.0, (x - 160) / 95) ** 2
    y = x + blacks + shadows + highlights + whites
    if args.dehaze < 0:
        haze = -args.dehaze
        y = y + 0.35 * haze * (1 - x / 255) ** 2 + 0.0015 * haze * (128 - y)
    return y


def interpolate(points, x):
    """The monotone cubic FilmLook.ToneCurve draws through its points."""
    if x <= points[0][0]:
        return points[0][1]
    if x >= points[-1][0]:
        return points[-1][1]
    count = len(points)
    widths = [points[i + 1][0] - points[i][0] for i in range(count - 1)]
    slopes = [(points[i + 1][1] - points[i][1]) / widths[i] for i in range(count - 1)]
    tangents = [slopes[0]] + [0.0] * (count - 2) + [slopes[-1]]
    for i in range(1, count - 1):
        if slopes[i - 1] * slopes[i] > 0:
            left, right = 2 * widths[i] + widths[i - 1], widths[i] + 2 * widths[i - 1]
            tangents[i] = (left + right) / (left / slopes[i - 1] + right / slopes[i])
    segment = max(i for i in range(count - 1) if points[i][0] <= x)
    width = widths[segment]
    t = (x - points[segment][0]) / width
    return ((2 * t**3 - 3 * t**2 + 1) * points[segment][1] + (t**3 - 2 * t**2 + t) * width * tangents[segment]
            + (-2 * t**3 + 3 * t**2) * points[segment + 1][1] + (t**3 - t**2) * width * tangents[segment + 1])


def main():
    parser = argparse.ArgumentParser()
    for name in ("highlights", "shadows", "whites", "blacks", "dehaze"):
        parser.add_argument("--" + name, type=float, default=0)
    parser.add_argument("--black-node", type=float, default=0, help="percent of the scale the bottom-left node is raised to")
    parser.add_argument("--then", default="", help='a point curve applied afterwards, as "in,out in,out ..."')
    args = parser.parse_args()
    after = [tuple(float(v) for v in pair.split(",")) for pair in args.then.split()] if args.then else None

    points = []
    for x in (0, 16, 32, 64, 96, 128, 160, 192, 224, 255):
        y = min(max(basic(x, args), 0), 255)
        if after:
            y = interpolate(after, y)
        points.append((x, min(max(y, 0), 255)))
    # A curve must rise; a pair of sliders pushed against each other can flatten it.
    for index in range(1, len(points)):
        if points[index][1] <= points[index - 1][1]:
            points[index] = (points[index][0], points[index - 1][1] + 0.5)
    # ToneCurve takes the shape from black (0) to white (255) and the print's black and white separately.
    black, white = points[0][1], points[-1][1]
    shape = [(x, (y - black) / (white - black) * 255) for x, y in points]
    if args.black_node:
        # The node sets where black prints, whatever the Basic values did to the black end.
        black = args.black_node / 100 * 255
    print("points: [" + ", ".join("CGPoint(x: %d, y: %.1f)" % point for point in shape) + "]")
    print("black: %.3f, white: %.3f" % (black / 255, white / 255))

if __name__ == "__main__":
    main()
