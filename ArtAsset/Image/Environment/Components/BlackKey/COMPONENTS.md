# Open Meadow Ink Gouache - Component Breakdown

Reference map:
`../../MapConcepts/v02_multi_agent/04_open_meadow_ink_gouache/map_open_meadow_ink_gouache.png`

## Recommended layer order

1. Base meadow color
2. Warm-yellow meadow patches
3. Soft-green meadow patches
4. Teal curved wind-grass bands
5. Small grass and flower decorations
6. Rock components
7. Peach-tree components
8. Contact shadows / gameplay collision masks (create separately in engine)

## Generated component set

### 01_trees
- `peach_tree_large.png`
- `peach_tree_medium.png`
- `peach_tree_sapling.png`

### 02_rocks
- `moss_rock_crescent_cluster.png`
- `moss_rock_small_cluster.png`
- `moss_rock_single.png`

### 03_plants
- `flower_clump_pink.png`
- `flower_clump_white_yellow.png`
- `grass_tuft_teal.png`
- `grass_tuft_warm.png`

### 04_ground_patches
- `meadow_patch_warm_yellow.png`
- `wind_grass_band_teal_curve.png`
- `meadow_patch_soft_green.png`

All component previews use a pure black background for chroma/luma-key extraction. Keep collision geometry independent from painted silhouettes.
