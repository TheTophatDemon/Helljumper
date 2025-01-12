#!/bin/sh
set -e
# For some reason on Linux building with -o:speed will cause a seg fault in the game after several minutes, so we will not do that for now.
odin build . 
odin build . -define:LANG=Russian -out:Helljumper_Russian
