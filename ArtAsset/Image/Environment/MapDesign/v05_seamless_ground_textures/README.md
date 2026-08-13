# v05 Seamless Ground Textures

Top-down hand-painted ink-and-gouache ground materials for the open meadow scene.

## Directory layout

- `raw/`: original GPT Image outputs, 1024x1024 PNG.
- `final/`: two-axis periodic-blended textures intended for game use, 1024x1024 PNG.
- `previews/`: 3x3 tiling checks plus a contact sheet.

## Texture set

- `meadow_jade_herbs.png`: fresh jade and celadon herb meadow with tiny ochre grass accents. Recommended neutral/default combat ground.
- `meadow_peach_petals.png`: muted spring green with sparse peach-pink petal flecks. Recommended around peach groves or restorative areas.
- `ground_rain_moss.png`: rain-dark teal moss and compact damp earth with mineral speckling. Recommended for ruins and wet areas.
- `meadow_autumn_straw.png`: warm ochre, straw yellow, khaki, and olive dry meadow. Recommended for late-wave or dry-biome variations.

## Shared generation constraints

- seamless repeating square texture in both axes
- strict 90-degree top-down orthographic ground only
- no trees, rocks, paths, borders, text, characters, props, horizon, or directional lighting
- no central focal point or large silhouettes
- low-to-medium contrast for gameplay readability
- hand-painted Chinese storybook ink-and-gouache brush language matching the existing open-meadow map

## Processing note

The `final/` images use a horizontal and vertical half-tile roll with sinusoidal feathering. This moves source-image edge discontinuities into blended interior regions while keeping the texture visually continuous when repeated. Use the files in `previews/*_3x3.jpg` to judge repetition at gameplay scale.
