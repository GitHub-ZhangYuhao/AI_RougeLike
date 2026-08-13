# v09 Crisp Cartoon Ground Refinement

This set redraws the eight v08 textures instead of relying on a simple sharpening filter.

## Goals

- Recognizable grass, soil, pebble, moss, and mineral shapes at first glance.
- Crisp medium-scale cartoon silhouettes rather than abstract watercolor masses.
- Limited clean palette and matte cel-gouache rendering.
- Remove paper grain, pigment speckles, airbrush haze, and high-frequency noise.
- Preserve quiet areas and irregular spacing to avoid heavy tile repetition.

## Processing

1. High-quality GPT Image edit using each v08 raw texture as the material source.
2. A selected v07 texture supplies the rounded cartoon style language.
3. Fourier periodic-component correction reduces border discontinuities without global mirrored blending.
4. Mild bilateral filtering removes isolated pigment noise while preserving shape edges.
5. Wrap-aware cubic upscale to 2048x2048.
6. Thresholded mild unsharp masking restores clean cartoon edges without sharpening flat areas excessively.

Measured fine residual after cleanup is lower than both the v08 input and the v09 generated raw image, while most dirt and marsh variants have stronger purposeful edge definition.

## Output

- `raw/`: high-quality 1024x1024 redraws.
- `final/`: cleaned, seamless 2048x2048 PNG textures.
- `previews/*_2x2.jpg`: repeated tile checks.
- `previews/v08_v09_before_after.jpg`: complete before/after comparison.
- `preview.html`: interactive before/after and tile-scale preview.
