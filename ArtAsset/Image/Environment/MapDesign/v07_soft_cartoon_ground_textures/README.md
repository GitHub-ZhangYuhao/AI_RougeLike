# v07 Soft Cartoon Ground Textures

This revision responds to two issues in the detailed v06 set: excessive repeated-tile visibility and material rendering that was too noisy/realistic.

## Changes

- Simplified cartoon cel-gouache material language.
- Broad asymmetric color regions instead of dense evenly distributed marks.
- Sparse rounded grass, pebble, and stone shapes.
- No global half-tile blending or mirrored-looking duplication.
- Fourier periodic-component correction removes low-frequency edge discontinuity while preserving interior painted detail.
- Final textures are wrap-aware upscaled from 1024 to 2048 so one tile can cover a larger world area.

## Files

- `raw/`: 1024x1024 original GPT Image paintings.
- `final/`: 2048x2048 seamless, wrap-aware upscaled PNG textures.
- `previews/`: 2x2 repeats and contact sheet.
- `preview.html`: interactive repeating preview with adjustable world tile scale.

## Textures

- `grass_soft_celadon.png`: quiet celadon/jade cartoon grass.
- `grass_dirt_soft_mix.png`: broad sage-grass and warm-soil transition regions.
- `dirt_soft_umber.png`: simplified warm umber soil.
- `dirt_sparse_pebbles.png`: quiet soil with widely spaced rounded pebbles.
- `stone_moss_soft.png`: sparse flat stones embedded in broad moss/earth areas.
- `flagstone_cartoon_soft.png`: large irregular cartoon ruin slabs without a masonry grid.

## Recommended rendering

Avoid displaying one full texture at very small world scale. Start with each 2048 texture covering roughly 900-1400 CSS/world pixels, then add separately randomized grass tufts, dirt patches, and rock decals. Random decals are more effective than baking many unique details into the repeating base texture.
