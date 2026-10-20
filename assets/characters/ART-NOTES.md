# v0.2.8 art integration

Built-in image generation was used for `doodle_layers.png` and `../environment/market_buildings.png`.

Character prompt: production transparent 3x3 modular top-down chibi atlas; top row black tousled hair, chestnut braided bun, golden curls; middle row cyan hoodie, coral jacket, mustard shirt; bottom row sneakers, navy backpack, phone. Isolated parts, forward up, soft painted raster shading, no labels or assembled bodies.

Building prompt: two isolated compact top-down cafe/shop sprites in equal side-by-side cells, terracotta/teal roofs and striped awnings, large human-scale entrances, no streets, people, text or baked shadows. Follow-up requested removal of all background/glow while retaining the two-cell positions.

Godot AtlasTexture regions trim each cell to alpha bounds once, sharing the original texture. Hair and clothing are separate draw layers; shoes move separately on the existing skeleton. The first version uses whole hair caps rather than separate fringe/back pieces. Hands and skin rims remain procedural circles to preserve the existing chibi silhouette and ragdoll.

The two storefronts are placed at (1900,-60) and (2800,-60), northwest/northeast of the east junction. The raster footprint is 360x400 world units. Front doors/activity thresholds are (1900,160) and (2800,160). Existing raster pavement is extended up to, but not across, the asphalt edge at y=250.
