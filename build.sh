#!/usr/bin/env bash
set -e

GAME_NAME="mobize"
LOVE_WIN_DIR="./love-win"
OUT_DIR="./dist-windows"

# 1) .love
rm -f "../$GAME_NAME.love"
( cd ./ && zip -9 -r "../$GAME_NAME.love" . -x "*.git*" "*node_modules/*" "*.love" "*__pycache__/*" "*.zip*" "*.aseprite*" "*dist-windows/*" "*love-win/*" )
mv "../$GAME_NAME.love" "./$GAME_NAME.love"

# 2) pasta de saída
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# 3) gerar exe único
cat "$LOVE_WIN_DIR/love.exe" "./$GAME_NAME.love" > "$OUT_DIR/$GAME_NAME.exe"

# 4) copiar DLLs e licenças
cp "$LOVE_WIN_DIR"/*.dll "$OUT_DIR"/
cp "$LOVE_WIN_DIR"/LICENSE.txt "$OUT_DIR"/ || true
cp "$LOVE_WIN_DIR"/changes.txt "$OUT_DIR"/ || true
cp "$LOVE_WIN_DIR"/readme.txt "$OUT_DIR"/ || true

echo "Build pronto em $OUT_DIR/"