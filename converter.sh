#!/bin/sh

# This program is a free software. You are free to use it under the terms of
# GNU GPL license either version 3 or, at your choice, any later version.
# Copyright 2019 Lucas V. Araujo <lucas.vieira.ar@disroot.org>
# Required tool: ImageMagick (imagemagick)

if [ -z "$1" ]; then
{
    echo "converter.sh - convert images to avoid errors while creating pdfs";
    echo "Usage: converter.sh <scans_directory>";
}
elif [ -d $1 ]; then
{
    for dir in `ls $1/`; do
    {
        if [ -d "$1/$dir" ]; then
        {
            echo "[+] Converting images from $dir ...";
            for img in `ls $1/$dir/*.jpg`; do
            {
                convert $img -compress none $img ;
                echo "[+] $img  -  [OK]";
            }
            done;
        }
        fi;
    }
    done;
}
else
{
    echo "[!] The directory is invalid or inexistent.";
}
fi;
