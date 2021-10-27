#!/bin/bash

workdir=$1

cd "${workdir}"

rm nes_header.bin >/dev/null 2>&1
beebasm -v -i nes_header.asm

rm bomberman.nes >/dev/null 2>&1
beebasm -v -i bman.asm
cat nes_header.bin bomberman bomber.chr > bomberman.nes

md5sum bomberman.nes
echo "97ddb647898b01065f395eb64c3d131f  Bomberman (USA)"
