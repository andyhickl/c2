#!/bin/bash

# Whoop Data Export Script
# Usage: ./whoop_export.sh <access_token> [start_date] [end_date]
#
# To get an access token:
# 1. Go to https://developer.whoop.com/developer-dashboard
# 2. Create an app and get your client credentials
# 3. Use the OAuth flow to get an access token, or use this curl command:
#
# curl -X POST "https://api.prod.whoop.com/oauth/oauth2/token" \
#   -H "Content-Type: application/x-www-form-urlencoded" \
#   -d "grant_type=authorization_code&client_id=YOUR_CLIENT_ID&client_secret=YOUR_CLIENT_SECRET&code=YOUR_AUTH_CODE&redirect_uri=YOUR_REDIRECT_URI"

ACCESS_TOKEN="$1"
START_DATE="${2:-$(date -d '30 days ago' '+%Y-%m-%d')}"
END_DATE="${3:-$(date '+%Y-%m-%d')}"
OUTPUT_FILE="whoop_data_$(date '+%Y%m%d_%H%M%S').csv"

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Usage: $0 <access_token> [start_date] [end_date]"
    echo "Example: $0 your_token_here 2025-07-01 2025-07-31"
    echo ""
    echo "To get an access token:"
    echo "1. Visit: https://developer.whoop.com/developer-dashboard"
    echo "2. Create an app and note your client_id and client_secret"
    echo "3. Get an authorization code through OAuth flow"
    echo "4. Exchange code for token using curl (see script comments)"
    exit 1
fi

echo "Fetching Whoop data from $START_DATE to $END_DATE..."
echo "Access Token: ${ACCESS_TOKEN:0:10}..."

# Create temporary files
RECOVERY_FILE=$(mktemp)
SLEEP_FILE=$(mktemp)
CYCLES_FILE=$(mktemp)

# Fetch Recovery Data
echo "Fetching recovery data..."
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
     -H "Accept: application/json" \
     "https://api.prod.whoop.com/developer/v1/recovery?start=${START_DATE}T00:00:00Z&end=${END_DATE}T23:59:59Z&limit=100" \
     > "$RECOVERY_FILE"

if [ $? -ne 0 ]; then
    echo "Error fetching recovery data"
    exit 1
fi

# Fetch Sleep Data
echo "Fetching sleep data..."
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
     -H "Accept: application/json" \
     "https://api.prod.whoop.com/developer/v1/activity/sleep?start=${START_DATE}T00:00:00Z&end=${END_DATE}T23:59:59Z&limit=100" \
     > "$SLEEP_FILE"

# Fetch Cycles Data (for strain)
echo "Fetching cycles data..."
curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
     -H "Accept: application/json" \
     "https://api.prod.whoop.com/developer/v1/cycle?start=${START_DATE}T00:00:00Z&end=${END_DATE}T23:59:59Z&limit=100" \
     > "$CYCLES_FILE"

# Process the JSON data and create CSV
echo "Processing data and creating CSV..."

# Create CSV header
echo "date,recovery,sleep_score,strain" > "$OUTPUT_FILE"

# Use Python to process JSON and create CSV (more reliable than bash JSON parsing)
python3 << 'EOF'
import json
import sys
from datetime import datetime
import os

# Read the temp file paths from environment
recovery_file = os.environ.get('RECOVERY_FILE')
sleep_file = os.environ.get('SLEEP_FILE')
cycles_file = os.environ.get('CYCLES_FILE')
output_file = os.environ.get('OUTPUT_FILE')

# Read and parse JSON files
try:
    with open(recovery_file, 'r') as f:
        recovery_data = json.load(f)
    with open(sleep_file, 'r') as f:
        sleep_data = json.load(f)
    with open(cycles_file, 'r') as f:
        cycles_data = json.load(f)
except Exception as e:
    print(f"Error reading JSON files: {e}")
    sys.exit(1)

# Create data dictionary by date
data_by_date = {}

# Process recovery data
recovery_records = recovery_data.get('records', [])
for record in recovery_records:
    if 'score' in record and record['score']:
        # Use created_at date for recovery
        date_str = record['created_at'][:10]  # Get YYYY-MM-DD
        if date_str not in data_by_date:
            data_by_date[date_str] = {}
        data_by_date[date_str]['recovery'] = record['score'].get('recovery_score', 0)

# Process sleep data
sleep_records = sleep_data.get('records', [])
for record in sleep_records:
    if 'score' in record and record['score']:
        # Use start date for sleep
        date_str = record['start'][:10]  # Get YYYY-MM-DD
        if date_str not in data_by_date:
            data_by_date[date_str] = {}
        data_by_date[date_str]['sleep_score'] = record['score'].get('sleep_performance_percentage', 0)

# Process cycles data for strain
cycles_records = cycles_data.get('records', [])
for record in cycles_records:
    if 'score' in record and record['score']:
        # Use start date for strain
        date_str = record['start'][:10]  # Get YYYY-MM-DD
        if date_str not in data_by_date:
            data_by_date[date_str] = {}
        data_by_date[date_str]['strain'] = record['score'].get('strain', 0)

# Write CSV data
with open(output_file, 'a') as f:
    for date, data in sorted(data_by_date.items()):
        recovery = data.get('recovery', 0)
        sleep_score = data.get('sleep_score', 0)
        strain = data.get('strain', 0)
        f.write(f"{date},{recovery},{sleep_score},{strain}\n")

print(f"Processed {len(data_by_date)} days of data")

EOF

# Set environment variables for Python script
export RECOVERY_FILE SLEEP_FILE CYCLES_FILE OUTPUT_FILE

# Check if Python script succeeded
if [ $? -eq 0 ]; then
    echo "Success! Whoop data exported to: $OUTPUT_FILE"
    echo "CSV format: date,recovery,sleep_score,strain"
    echo ""
    echo "Sample data:"
    head -5 "$OUTPUT_FILE"
    echo ""
    echo "Total records: $(tail -n +2 "$OUTPUT_FILE" | wc -l)"
else
    echo "Error processing data"
fi

# Clean up temporary files
rm -f "$RECOVERY_FILE" "$SLEEP_FILE" "$CYCLES_FILE"