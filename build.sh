#!/usr/bin/env bash
set -e

GAME_NAME="mobize"
LOVE_WIN_DIR="./love-win"
OUT_DIR="./dist-windows"

rm -f "./$GAME_NAME.love"
TMP_BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_BUILD_DIR"' EXIT

mkdir -p "$TMP_BUILD_DIR"
cp "./main.lua" "$TMP_BUILD_DIR/main.lua"
cp "./conf.lua" "$TMP_BUILD_DIR/conf.lua"

mkdir -p "$TMP_BUILD_DIR/scripts" "$TMP_BUILD_DIR/jumperj" "$TMP_BUILD_DIR/assets"
rsync -a --include='*/' --include='*.lua' --include='*.glsl' --exclude='*' "./scripts/" "$TMP_BUILD_DIR/scripts/"
rsync -a --include='*/' --include='*.lua' --exclude='*' "./jumperj/" "$TMP_BUILD_DIR/jumperj/"
rsync -a \
    --include='*/' \
    --include='*.png' \
    --include='*.mp3' \
    --include='*.ogg' \
    --include='*.wav' \
    --include='*.ttf' \
    --include='*.otf' \
    --exclude='*' \
    "./assets/" "$TMP_BUILD_DIR/assets/"

( cd "$TMP_BUILD_DIR" && zip -9 -r "$OLDPWD/$GAME_NAME.love" . )

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

cat "$LOVE_WIN_DIR/love.exe" "./$GAME_NAME.love" > "$OUT_DIR/$GAME_NAME.exe"


cp "$LOVE_WIN_DIR"/*.dll "$OUT_DIR"/
cp "$LOVE_WIN_DIR"/LICENSE.txt "$OUT_DIR"/ || true
cp "$LOVE_WIN_DIR"/changes.txt "$OUT_DIR"/ || true
cp "$LOVE_WIN_DIR"/readme.txt "$OUT_DIR"/ || true

echo "Build pronto em $OUT_DIR/"
