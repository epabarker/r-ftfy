# Logo

The source files for the ftfy hex logo. This directory is listed in
`.Rbuildignore`, so none of it goes into the package. The only image the
package ships is `man/figures/logo.png`.

| File | What it is |
|---|---|
| `logo.svg` | Source drawing, 480 × 556 |
| `../man/figures/logo.png` | `logo.svg` rendered at 480 × 556, used by the README and the pkgdown site |
| `ftfy-sticker.svg` | The same drawing as `logo.svg`, cropped to the hexagon and sized for print at 1.73 in × 2 in |
| `ftfy-sticker.pdf` | `ftfy-sticker.svg` as a PDF, for printing |
| `ftfy-sticker-300dpi.png` | The sticker at 300 dpi (520 × 600) |
| `ftfy-sticker-600dpi.png` | The sticker at 600 dpi (1039 × 1200) |

All the lettering is converted to vector outlines. No font is embedded in any
file, and none is needed to render them.

## Typefaces

| Typeface | Weight | Used for | Licence |
|---|---|---|---|
| [Space Grotesk](https://github.com/floriankarsten/space-grotesk) | Bold (700) | The "ftfy" wordmark (132 px, letter-spacing -4 px) and the large fixed "é" | SIL Open Font License 1.1, Copyright 2020 The Space Grotesk Project Authors |
| [JetBrains Mono](https://github.com/JetBrains/JetBrainsMono) | Medium (500) | The garbled "Ã©" with the wavy underline. The monospace face makes it read as raw, broken text. | SIL Open Font License 1.1, Copyright 2020 The JetBrains Mono Project Authors |

The OFL governs the font software. It places no condition on artwork made
with the fonts, and none of the font software is distributed here.

## Colours

| Name | Hex | Used for |
|---|---|---|
| Aubergine | `#3B1F4A` | Hexagon fill; primary colour of the pkgdown site |
| Mint | `#7EE0B5` | Hexagon border, the arrow and the fixed "é". Use it only on aubergine: on white its contrast is about 1.6:1. |
| Coral | `#F87171` | The wavy underline |
| Lilac | `#AE9BBA` | The garbled "Ã©" |

The wordmark is white (`#FFFFFF`).

## Licence

The artwork is the maintainer's own work, released under the Apache License,
Version 2.0, like the rest of the package. See `inst/COPYRIGHTS`.
