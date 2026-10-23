# Coastal texture source attribution

Nine original 1024×1024 JPG texture maps from [Poly Haven](https://polyhaven.com/), total7,068,490bytes: diffuse, OpenGL normal and roughness for three texture sets.

| Set | Authors | Official source |
| --- | --- | --- |
| Sparse Grass | Amal Kumar | https://polyhaven.com/a/sparse_grass |
| Sand03 | Charlotte Baglioni | https://polyhaven.com/a/sand_03 |
| Rock Boulder Dry | Dimitrios Savva (Photography), Rico Cilliers (Processing) | https://polyhaven.com/a/rock_boulder_dry |

The nine maps are [CC0-1.0](https://creativecommons.org/publicdomain/zero/1.0/); see the [provider license](https://polyhaven.com/license). This texture license does not cover the supplied Emma model or other game assets.

`manifest.json` records public attribution, sourceURLs, map roles, file sizes and MD5/SHA256 identities. Paths are relative to `godot/art/coast`. `*.files.json` retain public provider API metadata; `metadata-fetch-log.json` binds those files to their public endpoints and hashes. `download-log.json` binds the nine original image files to their public URLs and provider size/MD5 values. `image-inspection.json` lists dimensions, mode, role and SHA256. `research-evidence.json` contains public author, license and scale references only.

Diffuse uses sRGB; normal and roughness use linear non-color data. Source JPEG OpenGL normal maps are lossy8-bit originals. Official sample labels are grass2m wide, sand2m wide and rock1.8m tall; these labels are not independent measurements of scene UV scale. These are texture sets, not models.
