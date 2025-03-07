#!/bin/sh

currentDir=$(pwd)

# Copying the file from sourcemod to the git folder
cp -r ./play_to_earn_survival_db.sp ./nmrih/addons/sourcemod/scripting

# Compiling
cd ./nmrih/addons/sourcemod/scripting
./compile.sh play_to_earn_survival_db.sp

echo "Output: ./nmrih/addons/sourcemod/scripting/compiled/play_to_earn_survival_db.smx"