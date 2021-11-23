#!/bin/bash

workdir=$1

cd "${workdir}"

# Check header has changed before rebuilding
binhdr=`stat -c %Y nes_header.bin 2>/dev/null`
srchdr=`stat -c %Y nes_header.asm 2>/dev/null`

# No bin found so force build
if [ "${binhdr}" == "" ]
then
  binhdr=0
fi

# Source is newer than bin so build
if [ ${srchdr} -gt ${binhdr} ]
then
  rm nes_header.bin >/dev/null 2>&1
  beebasm -v -i nes_header.asm
fi

# Check code has changed before rebuilding
bincode=`stat -c %Y bomberman 2>/dev/null`
latestasm=`ls -larth *.asm | tail -1 | awk '{ print $NF }'`
srccode=`stat -c %Y ${latestasm} 2>/dev/null`

# No bin found so force build
if [ "${bincode}" == "" ]
then
  bincode=0
fi

# Source is newer than bin so build
if [ ${srccode} -gt ${bincode} ]
then
  rm bomberman.nes >/dev/null 2>&1
  beebasm -v -i bman.asm
  cat nes_header.bin bomberman bomber.chr > bomberman.nes

  md5sum bomberman.nes
  echo "97ddb647""898b0106""5f395eb6""4c3d131f""  Bomberman (USA)"
fi
