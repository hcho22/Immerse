# Immerse film looks - calibration tools (internal; supersedes the 6x6-only zip)

Needs: pip install --break-system-packages spectral_film_lut colour-science scikit-image scipy pillow
Put the generators (vision3_250d_lut.py, portra400_lut.py) and effects_16mm_reference.py next to these files.

- ref_stock.py    : reference renders from the spectral simulation for any negative / print pair
- fit_stock.py    : two-stage fit (tone on a grey ramp, then colour with tone locked)
                    python3 fit_stock.py vision3_250d_lut print "Kodak Vision3 250D 5207" "Kodak Vision 2383"
                    python3 fit_stock.py portra400_lut scan "Kodak Portra 400"
                    To calibrate to real scans, replace reference() with measured patch values.
- derive_stock.py : measures a shipped look (drift from simulation, LUT agreement, Lightroom curve, OKLab colour table)
- preview_16mm.py : 16mm contact sheet (incl. tungsten with daylight-locked WB) and a fully developed frame
