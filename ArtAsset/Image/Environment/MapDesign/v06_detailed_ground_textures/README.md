# v06 Detailed Ground Textures

A material-driven seamless ground set for top-down gameplay. This round adds recognizable grass, dirt, embedded stones, gravel, and worn stone surfaces while keeping the silhouettes flat enough for walkable terrain.

## Directory layout

- `raw/`: original GPT Image outputs, retaining the strongest painted detail.
- `final/`: periodic-blended 1024x1024 PNG textures recommended for repeating terrain fills.
- `previews/`: 3x3 tiling checks and the complete contact sheet.
- `preview.html`: live CSS repeating preview at a smaller gameplay-like scale.

## Texture set

### Grass
- `grass_lush_fine.png`: dense celadon grass with fine blade and herb detail.
- `grass_dry_tufted.png`: patchy olive and straw grass with exposed soil flecks.

### Dirt and mixed ground
- `dirt_compacted_warm.png`: compact warm umber earth with scuffs and pigment grain.
- `grass_dirt_trampled.png`: irregular trampled grass mixed with compact soil.
- `dirt_pebbled.png`: damp brown earth with many small embedded pebbles.

### Stone
- `stone_moss_cobbles.png`: flat moss-softened cobbles embedded in soil.
- `stone_flagstone_worn.png`: worn irregular flagstone with narrow moss seams.
- `gravel_blue_slate.png`: small blue-gray slate gravel with muted earth between pieces.

## Usage guidance

- Use grass and dirt textures as large-area base fills.
- Use the mixed grass/dirt texture to break up large uniform zones or transition between biomes.
- Use cobbles and flagstones for ruins, shrines, extraction points, and settlement areas.
- Use gravel for riverbanks, mineral regions, and the edge of stone structures.
- Large raised rocks should remain separate decoration/collision assets. Stones in these textures are painted as embedded, walkable detail without cast shadows.
