# Monivo Omani Rial

One glyph: **U+20C4 OMANI RIAL SIGN**, the symbol the Central Bank of Oman
introduced on 19 November 2025 (Unicode 18.0). No system font draws it yet, so
the app bundles it and lists it as a fallback after Manrope
(`AppTypography.fontFamilyFallback`).

- **Source:** the Central Bank of Oman's artwork, as published on Wikimedia
  Commons (`Omani_rial_black_light.svg`, `_medium.svg`, `_bold.svg`), where it
  is marked public domain (simple geometry; an official currency symbol).
- **Built with** `build_font.py` (fontTools): each weight's outline is scaled
  to Manrope's cap height and set on the baseline, with Manrope's vertical
  metrics, so a line that contains the sign is never taller than one that
  doesn't. Weights: Light 300, Medium 500, Bold 700.
- **Usage rules** (the Central Bank's guidelines): the sign goes to the left
  of the number, with a space, at the height of the figures.
  `CurrencyFormatter` adds the space.

To rebuild: `python3 build_font.py <dir with the three SVGs> <out dir>`.
