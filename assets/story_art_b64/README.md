# Curated story-art payload

The preferred payload is the byte-exact archive:

`assets/story_art_b64/story_art_v12_curated.zip`

`tools/install_curated_story_art.py` reads that ZIP without re-encoding any image, securely extracts it, and validates every installed file against `story_art/story_art_manifest.json` using both byte size and SHA-256.

For text-only repository connectors, files named `story_art_bundle_part_*.b64` remain supported as a lossless fallback. They form one Base64 stream: concatenate them in lexical order and decode once to recreate the original ZIP byte for byte.

Art direction:

- the player protagonist always wears the dark hood and the eyes remain fully hidden;
- named characters use separate identity IDs and must not share the same face;
- group scenes with visibly duplicated disciple faces are excluded;
- female leads use distinct silhouettes, hairstyles, occupations and expressions;
- restrained blue-grey, jade and moonlit palettes are preferred over excessive saturation.

Reference archive integrity for v1.2:

`sha256 cc8ab95416ee8351656aef661cf56fd71cf5fb5dfd899042d0e583e70f323e3c`
