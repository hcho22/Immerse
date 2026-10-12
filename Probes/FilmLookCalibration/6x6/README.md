# 6x6 color look - calibration tools (internal)

Needs: pip install --break-system-packages spectral_film_lut colour-science scikit-image scipy pillow
Put portra400_lut.py next to these files.

- ref_eval.py  : renders reference values from the spectral simulation (Portra 400 -> scan or Endura print)
- fit.py       : two-stage fit (tone on the grey ramp, then colour with tone locked).  python3 fit.py scan|print
                 -> fit_<look>.json. To calibrate to real scans, replace reference() with your measured patch values.
- derive.py    : measures the shipped LUT (Lightroom tone curve, per-colour OKLab behaviour, drift from simulation)
- preview.py   : before/after contact sheet through the actual .cube and the app's input path
