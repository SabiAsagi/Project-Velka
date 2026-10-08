# Third-party assets

This directory contains third-party game assets that are safe to redistribute with the project.

## Kenney Furniture Kit

- Source: https://kenney.nl/assets/furniture-kit
- Downloaded: 2026-07-16
- License: Creative Commons Zero (CC0 1.0)
- Original author/distributor: Kenney
- Included files: GLB models and the original `LICENSE.txt`
- Usage in Velka: classroom and office desks, chairs, tables, shelves, computers, sanitary fixtures, kitchen equipment, benches, boxes, plants, and small interior props.

## Kenney City Kit (Suburban) 2.0

- Source: https://kenney.nl/assets/city-kit-suburban
- Downloaded: 2026-07-16
- License: Creative Commons Zero (CC0 1.0)
- Original author/distributor: Kenney
- Included files: GLB models and the original `LICENSE.txt`
- Usage in Velka: old trees, planters, fences, and exterior path details.

The license text supplied with each pack is stored next to its model files.

## Additional Kenney kits

The following packs were downloaded on 2026-07-16. Each source page and the
bundled `LICENSE.txt` identify the pack as Creative Commons Zero (CC0 1.0).
Only the GLB models used by the school map were copied into the repository.

| Pack | Source | Velka usage |
| --- | --- | --- |
| Factory Kit 3.0 | https://kenney.nl/assets/factory-kit | Boiler-room pipes, machinery, crates, and backstage equipment |
| City Kit Roads 2.0 | https://kenney.nl/assets/city-kit-roads | Entrance road, crossing, driveway, lamps, and safety barriers |
| Retro Urban Kit 2.0 | https://kenney.nl/assets/retro-urban-kit | Weathered benches, masonry details, pallets, and service-yard props |
| Mini Market | https://kenney.nl/assets/mini-market | School store shelves, freezer, displays, baskets, and register |
| Food Kit 2.0 | https://kenney.nl/assets/food-kit | Cafeteria serving-line and table food props |
| Building Kit | https://kenney.nl/assets/building-kit | Gutters, columns, roof repairs, pipes, doors, and short utility stairs |
| Nature Kit | https://kenney.nl/assets/nature-kit | Mature trees, shrubs, grass clumps, and flower-bed plants |

## Screaming Brain Studios Horror Texture Pack

- Source: https://screamingbrainstudios.itch.io/horror-texture-pack
- Downloaded: 2026-07-16
- License: Creative Commons Zero (CC0 1.0 / Public Domain)
- Original author: Screaming Brain Studios
- Included files: seven selected 128x128 PNG textures and the original `LICENSE.txt`
- Usage in Velka: subtle worn brick, plaster, floor, roof, and metal surfaces. Blood,
  heavy decay, and ruin-focused textures were deliberately excluded so the school
  reads as old and actively used rather than abandoned.

The offered PSX packs with no explicit redistribution grant, or with third-party
textures that forbid redistribution, are not copied into this source repository.

## ambientCG PBR textures (school surfaces)

- Source: https://ambientcg.com (each asset page: `https://ambientcg.com/a/<AssetId>`)
- Downloaded: 2026-10-06 (1K-JPG packages)
- License: Creative Commons Zero (CC0 1.0), see https://ambientcg.com/license
- Original author/distributor: ambientCG (Lennart Demes)
- Included files: `<AssetId>_Color.jpg` and `<AssetId>_NormalGL.jpg` only (`Leaking001` also keeps
  `_Opacity.jpg`). Maps were resized to 1024 or 512 px and re-encoded as JPG (quality 88).
- Usage in Velka: `assets/shaders/school_surface.gdshader` projects them in world space (buildings, ground)
  or box space (furniture). `tools/level_gen/school/palette_tex.py` assigns them per material, and the
  shader divides by each texture's average color (`tools/level_gen/school/texture_stats.json`) so the
  palette color stays the surface's average color and the texture only adds pattern and wear.

| Asset | Velka usage |
| --- | --- |
| Terrazzo005 | Corridor, lobby and stair terrazzo |
| Terrazzo019S | Speckled vinyl floors (offices, labs, nurse room, cafeteria) |
| WoodFloor065B | Old classroom strip floor, flooded old library floor |
| WoodFloor061 | Gym maple floor |
| WoodFloor064 | Principal/music room and stage floors |
| Tiles141 | Toilet and kitchen floor tiles |
| Tiles107 | Toilet and cafeteria wall tiles |
| Carpet001 | Carpet floors (library, broadcast room) |
| Concrete030 | Site concrete, stands, stairs, plain concrete walls, court |
| Concrete032 | B1 floors and walls, basement exterior |
| Concrete034 | Exterior facades, chalkboard smudges |
| Concrete035 | B1 wall base band, garden stones |
| PaintedPlaster017 | Interior painted plaster walls |
| PaintedPlaster003 | Chipped green wainscot paint in corridors |
| Leaking001 | Water-leak stains on walls (opacity map) |
| Bricks089 | Stone retaining walls |
| Road015A | Roads and parking lot asphalt |
| PavingStones099 | Interlocking sidewalk pavers and plazas |
| Ground102 | Athletic field (compacted dirt) |
| Ground091 | Walking trail and sand |
| Ground104 | Soil beds, planters and earth cut |
| Grass004 | Lawns and grass banks |
| ScatteredLeaves009 | Forest floor |
| Moss002 | Tree crowns, hedges and shrubs |
| Bark014 | Tree trunks |
| Rubber004 | Fitness-area rubber mats |
| Wood049 | Wooden furniture; source of the derived door texture |
| PaintedWood008C | Old and water-damaged shelves |
| PaintedMetal002 | Source of the derived painted-door texture |
| PaintedMetal012 | Outdoor painted steel (fences, rails, fitness equipment) |
| Metal016 | Bare and stainless steel, window frames, canopies |
| CorrugatedSteel003 | Gym roof sheet metal |
| Plastic018B | Plastic props and indoor painted steel furniture |
| Fabric036 | Curtains, sofas, mats, bags |
| Cardboard004 | Boxes and file boxes |
| Planks023A | Pallets |

Derived files in `assets/textures/school` (generated by `tools/level_gen/school/texture_tool.gd`):
`surface_noise.png` (procedural noise, no third-party content), `DoorWood_Color.jpg` (Wood049 rotated,
lower contrast) and `DoorPaint_Color.jpg` (PaintedMetal002 in grayscale, lower contrast).

The Screaming Brain Studios textures above are now also used by the school shader: `Horror_Floor_01`
(rooftop waterproof coating), `Horror_Floor_10` (gym exterior steel stair), and `Horror_Wall_02`,
`Horror_Wall_06`, `Horror_Wall_09` as fine grime overlays on painted walls, facades and concrete.

## Nanum fonts (나눔 글꼴)

- Source: https://github.com/google/fonts (`ofl/nanumpenscript`, `ofl/nanumgothiccoding`, `ofl/nanummyeongjo`)
- Downloaded: 2026-10-08
- License: SIL Open Font License 1.1 (`assets/fonts/OFL.txt`)
- Original author: NAVER Corporation (Sandoll Communication)
- Included files: `assets/fonts/NanumPenScript-Regular.ttf`, `NanumGothicCoding-Regular.ttf`, `NanumGothicCoding-Bold.ttf`, `NanumMyeongjo-Regular.ttf`, `NanumMyeongjo-Bold.ttf`
- Usage in Velka: UI titles and documents (명조), handwritten memos on the investigation board (펜), hacking terminal (고딕 코딩)
