# Curated story-art payload

The files named `story_art_bundle_part_*.b64` form one Base64 stream. Concatenate them in lexical order and decode the result as a ZIP archive. `tools/install_story_art.py` performs secure extraction and validates every installed image against `story_art/story_art_manifest.json`.

Art direction:

- the player protagonist always wears the dark hood and the eyes remain fully hidden;
- named characters use separate identity IDs and must not share the same face;
- group scenes with visibly duplicated disciple faces are excluded;
- female leads use distinct silhouettes, hairstyles, occupations and expressions;
- restrained blue-grey, jade and moonlit palettes are preferred over excessive saturation.
