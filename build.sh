#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Step 1: Install dependencies using pnpm
echo "Installing dependencies..."
pnpm install

# Step 2: Initialize and update git submodules recursively
echo "Initializing and updating submodules..."
cd lib/core
git submodule update --init --recursive
git pull origin main
cd ../..

# Step 3: Clear any previous builds (optional step depending on your needs)
echo "Clearing previous builds..."
forge clean

# Step 4: Build the project
echo "Building the project..."
forge build

# Step 5: Run tests
echo "Running tests..."
forge test -vvv

echo "Build and tests completed successfully!"
