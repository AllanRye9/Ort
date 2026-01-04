#!/bin/bash

set -e
# -----------------------------
echo "Starting to install dependencies..."

pip install --upgrade pip
pip install -r requirements/base.txt

echo "Dependencies installed."
# ----------------------------