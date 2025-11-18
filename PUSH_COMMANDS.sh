#!/bin/bash

# Navigate to repository
cd /mnt/c/Users/rickh/OneDrive/Documents/GitHub/json-document-modeling-livelab

# Add remote (replace with your actual GitHub username if different)
git remote add origin https://github.com/rhoulihan/json-document-modeling-livelab.git

# Verify remote
git remote -v

# Push to GitHub
git push -u origin main

echo "✅ Repository pushed to GitHub successfully!"
echo "📍 View at: https://github.com/rhoulihan/json-document-modeling-livelab"
