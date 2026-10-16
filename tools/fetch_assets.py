#!/usr/bin/env python3
"""Downloads the third-party CC0 assets the game uses into assets/third_party/ and writes
assets/third_party/CREDITS.md (3DMODELS.md §13: track license and provenance of every sourced file).

Re-running is safe: files already present are skipped. Only CC0 sources are listed here; adding a
non-CC0 asset needs an explicit license review first.

    python3 tools/fetch_assets.py
"""
import io
import json
import pathlib
import sys
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "third_party"
RES = "1k"

# Poly Haven models (CC0). id -> purpose
POLYHAVEN_MODELS = {
    "antique_katana_01": "hero katana (blade, tsuba, tsuka, saya reference)",
    "katana_stand_01": "dojo weapon rack prop",
    "wooden_crate_01": "market / road prop",
    "wooden_crate_02": "loot cache placeholder",
    "wooden_bucket_01": "well / village prop",
    "stone_fire_pit": "camp at the frontier crossing",
    "rock_07": "rock cover",
    "rock_09": "rock cover",
    "rock_moss_set_01": "ruin rubble",
    "tree_stump_01": "bamboo clearing stump",
    "fern_02": "ground foliage",
    "shrub_03": "ground foliage",
    "painted_wooden_bench": "village bench",
}

# Poly Haven textures (CC0). id -> purpose
POLYHAVEN_TEXTURES = {
    "raked_dirt": "village streets",
    "stone_pathway": "roads",
    "leafy_grass": "frontier ground",
    "forest_leaves_02": "bamboo grove floor",
    "playground_sand": "duel ring",
    "hinoki_planks": "dojo floor, verandas",
    "tatami_mat": "dojo interior",
    "japanese_cedar_planks": "timber walls",
    "white_plaster_rough_01": "plaster walls",
    "grey_roof_tiles": "tiled roofs",
    "thatch_roof_angled": "thatched roofs",
    "japanese_stone_wall": "foundations, ruin walls",
    "mossy_rock": "ruin stones",
    "japanese_cedar_bark": "timber posts",
}

# Poly Haven HDRIs (CC0). id -> (resolution, purpose)
POLYHAVEN_HDRIS = {
    "belfast_sunset_puresky": ("2k", "province sky and image-based lighting"),
}

# Zip packs: (folder, url, members-to-keep prefix list, title, source page)
ZIPS = [
    ("quaternius_ual1", "https://opengameart.org/sites/default/files/universal_animation_librarystandard.zip",
     ["Godot/AnimationLibrary_Godot_Standard.glb", "License.txt"],
     "Universal Animation Library (Standard) by Quaternius",
     "https://quaternius.com/packs/universalanimationlibrary.html"),
    ("quaternius_ual2", "https://opengameart.org/sites/default/files/universal_animation_library_2standard.zip",
     ["Unreal-Godot/UAL2_Standard.glb", "License.txt"],
     "Universal Animation Library 2 (Standard) by Quaternius",
     "https://opengameart.org/content/universal-animation-library-2"),
    ("kenney_rpg_audio", "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
     ["Audio/", "License.txt"], "RPG Audio by Kenney", "https://kenney.nl/assets/rpg-audio"),
    ("kenney_impact_sounds", "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
     ["Audio/", "License.txt"], "Impact Sounds by Kenney", "https://kenney.nl/assets/impact-sounds"),
    ("kenney_interface_sounds", "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
     ["Audio/", "License.txt"], "Interface Sounds by Kenney", "https://kenney.nl/assets/interface-sounds"),
]

# Single files: (folder, filename, url, title, source page)
GF = "https://github.com/google/fonts/raw/main/ofl"
FILES = [
    ("fonts/inter", "Inter.ttf", f"{GF}/inter/Inter%5Bopsz,wght%5D.ttf",
     "Inter by Rasmus Andersson (SIL OFL 1.1)", "https://github.com/google/fonts/tree/main/ofl/inter"),
    ("fonts/inter", "OFL.txt", f"{GF}/inter/OFL.txt", "Inter license", "https://github.com/google/fonts/tree/main/ofl/inter"),
    ("fonts/cormorant", "CormorantGaramond.ttf", f"{GF}/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf",
     "Cormorant Garamond by Christian Thalmann (SIL OFL 1.1)", "https://github.com/google/fonts/tree/main/ofl/cormorantgaramond"),
    ("fonts/cormorant", "OFL.txt", f"{GF}/cormorantgaramond/OFL.txt", "Cormorant license", "https://github.com/google/fonts/tree/main/ofl/cormorantgaramond"),
    ("oga_crickets", "crickets.mp3", "https://opengameart.org/sites/default/files/crickets.mp3",
     "Crickets Ambient Noise (loopable) by Wolfgang_", "https://opengameart.org/content/crickets-ambient-noise-loopable"),
]


# Credits-only entries: files committed in the repo that this script does not download.
# Sketchfab models (CC BY 4.0) need a signed-in download; the raw GLTF archives are reduced to
# assets/third_party/sketchfab/<key>/<key>.glb by tools/optimize_models.gd. Attribution is required.
SKETCHFAB = [
    # (key, title, author, model uid, used for)
    ("ninja", "Ninja", "histrix88", "79c6a037c4864aeeb170db9feab8e600", "playable assassin body (4K PBR, Mixamo rig)"),
    ("torii", "Japanese Torii gate Game Asset", "Bazylonator", "e12d2fa1b2b94928b8b87cb7787e2462", "frontier torii, menu set"),
    ("pagoda", "Japanese Temple", "Jainesh Pathak", "a210febbec4f454dbd0df1d142be06bc", "village pagoda landmark"),
    ("shrine_hall", "Japanese shrine", "GreenG", "56baeb7b13ba4238a2f54c363e7a3e0b", "dojo hall"),
    ("farmhouse", "Shirakawago Village Set House 1", "Lokomotto", "f94da738aefc4674ab2062df5c01cd43", "village farmhouses"),
    ("machiya_kit", "Japanese Machiya Set Kit", "xervolt", "d0bb3d915bf9448a9ef46bcb6a6fa6db", "town kit (reserved)"),
    ("castle", "Japanese Castle", "Zorodroger", "a37d9de4c8dc4f2da25698bb2028b10a", "skyline castle"),
    ("stone_lantern", "Japanese Stone Lantern", "Sahir Virmani", "e0417d1e05984727a50f9ab1451d162d", "stone lanterns"),
    ("bridge", "Japanese Wood Bridge", "btitkin95", "9d483d5e092544b38ee98abccce55249", "stream bridge (reserved)"),
    ("maple", "Japanese Maple", "endlessvoidmc", "003c6ab20e644655ba36fe54cb04765b", "ornamental maples"),
    ("bamboo", "Free Bamboo Set", "JonhGillessen", "e9f9fa5397814f81bf85ad06acf5bf30", "bamboo (reserved)"),
    ("cherry", "Japanese Cherry Tree (medium-Poly)", "Sereib", "e0306a4402b44fa08f55aa58518dcb9c", "cherry trees"),
    ("pines", "Pine trees pack (lowpoly, game ready, LODs)", "LOLIPOP", "e1e9c07b8e2e445c943fec660beefba2", "hillside forest (LODs, billboards)"),
]
# game-icons.net glyphs (CC BY 3.0), by author.
GAME_ICONS = {
    "Lorc": ["cowled", "lightning-arc", "lotus", "ninja-mask", "snowflake-1", "spark-spirit", "cog", "compass", "crossed-swords", "emerald", "feather", "lotus-flower", "meditation",
             "scroll-unfurled", "shield-reflect", "skull-crossed-bones", "sprint", "sword-clash", "sword-slice"],
    "Delapouite": ["coins", "exit-door", "japan", "katana", "kimono", "pagoda", "samurai-helmet", "shopping-bag"],
    "Felbrigg": ["dodge"],
    "Carl Olsen": ["flame"],
    "DarkZaitzev": ["ninja-heroic-stance"],
}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "kage-asset-fetch/1"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def save(path: pathlib.Path, url: str) -> None:
    if path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    print("  ", path.relative_to(ROOT))
    path.write_bytes(fetch(url))


def polyhaven_model(asset_id: str) -> None:
    files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset_id}"))
    gltf = files["gltf"][RES]["gltf"]
    folder = OUT / "polyhaven" / "models" / asset_id
    save(folder / f"{asset_id}.gltf", gltf["url"])
    for rel, inc in gltf["include"].items():
        save(folder / rel, inc["url"])


def polyhaven_texture(asset_id: str) -> None:
    files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset_id}"))
    folder = OUT / "polyhaven" / "textures" / asset_id
    for key, suffix in (("Diffuse", "diff"), ("nor_gl", "nor_gl"), ("arm", "arm")):
        if key in files:
            save(folder / f"{asset_id}_{suffix}_{RES}.jpg", files[key][RES]["jpg"]["url"])


def polyhaven_hdri(asset_id: str, res: str) -> None:
    files = json.loads(fetch(f"https://api.polyhaven.com/files/{asset_id}"))
    save(OUT / "polyhaven" / "hdris" / f"{asset_id}_{res}.hdr", files["hdri"][res]["hdr"]["url"])


def zip_pack(folder: str, url: str, keep: list[str]) -> None:
    dest = OUT / folder
    if dest.exists() and any(dest.iterdir()):
        return
    print("  ", dest.relative_to(ROOT), "(zip)")
    with zipfile.ZipFile(io.BytesIO(fetch(url))) as z:
        # Some packs wrap everything in one top-level folder; strip it only when it exists.
        tops = {pathlib.PurePosixPath(n).parts[0] for n in z.namelist()}
        strip = 1 if len(tops) == 1 else 0
        for info in z.infolist():
            if info.is_dir():
                continue
            # Refuse anything that would escape `dest`.
            parts = pathlib.PurePosixPath(info.filename).parts
            rel = pathlib.PurePosixPath(*parts[strip:])
            if not any(str(rel).startswith(k) for k in keep) or ".." in rel.parts or rel.is_absolute():
                continue
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(z.read(info))


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    print("Poly Haven models")
    for a in POLYHAVEN_MODELS:
        polyhaven_model(a)
    print("Poly Haven textures")
    for a in POLYHAVEN_TEXTURES:
        polyhaven_texture(a)
    print("Poly Haven HDRIs")
    for a, (res, _) in POLYHAVEN_HDRIS.items():
        polyhaven_hdri(a, res)
    print("Packs")
    for folder, url, keep, _, _ in ZIPS:
        zip_pack(folder, url, keep)
    for folder, name, url, _, _ in FILES:
        save(OUT / folder / name, url)
    write_credits()
    return 0


def write_credits() -> None:
    lines = [
        "# Third-party asset credits",
        "",
        "Generated by `tools/fetch_assets.py`. Licenses: Poly Haven, Quaternius, Kenney and the",
        "ambience are **CC0 1.0** (attribution given anyway). Sketchfab models are **CC BY 4.0** and",
        "game-icons.net glyphs **CC BY 3.0**: attribution required, as listed below. Fonts under `fonts/`",
        "are **SIL Open Font License 1.1** (license text next to each font).",
        "",
        "| Folder | Asset | Source | Used for |",
        "|---|---|---|---|",
    ]
    for a, use in POLYHAVEN_MODELS.items():
        lines.append(f"| polyhaven/models/{a} | {a} (Poly Haven) | https://polyhaven.com/a/{a} | {use} |")
    for a, use in POLYHAVEN_TEXTURES.items():
        lines.append(f"| polyhaven/textures/{a} | {a} (Poly Haven) | https://polyhaven.com/a/{a} | {use} |")
    for a, (res, use) in POLYHAVEN_HDRIS.items():
        lines.append(f"| polyhaven/hdris/{a}_{res}.hdr | {a} (Poly Haven) | https://polyhaven.com/a/{a} | {use} |")
    for folder, _, _, title, page in ZIPS:
        lines.append(f"| {folder} | {title} | {page} | see art/ wrappers |")
    for folder, name, _, title, page in FILES:
        if name.endswith(".txt"):
            continue
        use = {"fonts": "UI typography"}.get(folder.split("/")[0], "night ambience")
        lines.append(f"| {folder}/{name} | {title} | {page} | {use} |")
    lines.append("| fonts/yuji_boku/YujiBoku-Kage-subset.ttf | Yuji Boku by Kinuta Font Factory (SIL OFL 1.1), subset | https://github.com/google/fonts/tree/main/ofl/yujiboku | brush calligraphy glyphs |")
    for key, title, author, uid, use in SKETCHFAB:
        lines.append(f"| sketchfab/{key} | \"{title}\" by {author} (CC BY 4.0) | https://sketchfab.com/3d-models/{uid} | {use} |")
    for author, icons in GAME_ICONS.items():
        lines.append(f"| game_icons | {', '.join(icons)} by {author} (CC BY 3.0) | https://game-icons.net | UI icons |")
    lines += [
        "",
        "## Engine plugins (committed under addons/)",
        "",
        "| Folder | Plugin | Source | Used for |",
        "|---|---|---|---|",
        "| addons/terrain_3d | Terrain3D 1.0.2 by Cory Petkovsek, Roope Palmroos and contributors (MIT) | https://github.com/TokisanGames/Terrain3D | province terrain, grass instancing |",
    ]
    (OUT / "CREDITS.md").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
