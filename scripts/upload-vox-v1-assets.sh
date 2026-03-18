#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Uploading curated Vox v1 assets to Supabase Storage..."
echo "Expected linked project: mbfyewvolvqyarrafugu"

supabase --experimental storage cp "$ROOT_DIR/assets/6A3DE1A3-ED25-4FC2-93D8-8FFA0FE3A1E1_1_105_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/images/bastidor-vv/vox-lisbon-cafe-v1.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"
supabase --experimental storage cp "$ROOT_DIR/assets/CDDB8DD0-4880-422E-A1C1-EE243D4E44D8_4_5005_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/images/lounge-casa/vox-lounge-sofa-01.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"
supabase --experimental storage cp "$ROOT_DIR/assets/D94AE285-CC95-46CE-A7DA-816ACB696FC1_4_5005_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/images/lounge-casa/vox-lounge-sofa-frontal-01.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"
supabase --experimental storage cp "$ROOT_DIR/assets/E4588043-5ED5-458F-BE36-A260C24A89D9_4_5005_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/images/praia-solar/vox-beach-run-01.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"
supabase --experimental storage cp "$ROOT_DIR/assets/6FCD7E49-127C-4866-94B8-F171D622D20F_4_5005_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/references/vox-turnaround-cap-01.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"
supabase --experimental storage cp "$ROOT_DIR/assets/02124318-C788-42BB-BD1E-65E7A8635DF7_1_105_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/references/brand/voulezvous-logo-black-pink-01.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"
supabase --experimental storage cp "$ROOT_DIR/assets/23A01D2B-4C68-42D8-A5FE-22D6D75D4C67_1_105_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/references/brand/voulezvous-logo-neon-pink-01.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"
supabase --experimental storage cp "$ROOT_DIR/assets/3F216654-6647-4E6A-B34E-E616E64E8EAC_1_105_c.jpeg" "ss:///vox-assets/workspaces/voulezvous/characters/vox/references/brand/voulezvous-logo-white-pink-01.jpeg" --workdir "$ROOT_DIR" --content-type image/jpeg --cache-control "max-age=31536000"

echo "Upload complete. Next: run docs/assets-bootstrap.sql in Supabase SQL Editor."
