#!/bin/bash

rm -r log_emulation

git clone http://github.org/karokarov/log_emulation.git log_emulation

cd log_emulation
chmod +x setup.sh

./setup.sh
