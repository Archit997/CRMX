#!/usr/bin/env bash

set -euo pipefail

echo "Running tests..."
pytest -v

echo "Checking Python compilation..."
python -m compileall main.py core

echo "Testing application import..."
python -c "from main import app; print('App import successful:', app.title)"

echo "Deployment checks passed."