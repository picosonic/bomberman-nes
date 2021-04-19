#!/bin/bash

workdir=$1

cd "${workdir}"

rm bomberman.nes >/dev/null 2>&1
beebasm -v -i bman.asm
cat nes_header.bin bomberman bomber.chr > bomberman.nes
