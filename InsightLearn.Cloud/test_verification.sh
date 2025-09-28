#!/bin/bash
set -e

echo "Testing individual commands..."

echo "1. Testing free command:"
free -h | grep '^Mem:' | awk '{print $2}'

echo "2. Testing df command:"
df -h / | awk 'NR==2 {print $2}'

echo "3. Testing lscpu command:"
lscpu | grep "Model name" | cut -d':' -f2 | sed 's/^ *//'

echo "4. Testing nproc command:"
nproc

echo "All tests completed!"