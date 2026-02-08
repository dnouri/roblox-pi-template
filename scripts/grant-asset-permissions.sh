#!/bin/bash
# Grant asset permissions to the experience via Roblox Open Cloud API
#
# Scans source files for Roblox asset IDs and grants "Use" permission
# to the universe/experience specified in .env
#
# Requires:
#   - ROBLOX_OPEN_CLOUD_API_KEY in .env (with asset-permissions:write scope)
#   - ROBLOX_UNIVERSE_ID in .env
#
# API Reference: https://create.roblox.com/docs/reference/cloud/asset-permissions-api/v1.json

set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Check required variables
if [ -z "$ROBLOX_OPEN_CLOUD_API_KEY" ]; then
    echo "Error: ROBLOX_OPEN_CLOUD_API_KEY not set in .env"
    echo ""
    echo "To create an API key:"
    echo "1. Go to https://create.roblox.com/dashboard/credentials"
    echo "2. Create a new API key"
    echo "3. Add 'asset-permissions' to Access Permissions"
    echo "4. Enable 'Write' operation"
    echo "5. Add the key to .env as ROBLOX_OPEN_CLOUD_API_KEY=your-key"
    exit 1
fi

if [ -z "$ROBLOX_UNIVERSE_ID" ]; then
    echo "Error: ROBLOX_UNIVERSE_ID not set in .env"
    exit 1
fi

# Find all 10+ digit numbers assigned to asset-like fields in src/
echo "Scanning source files for asset IDs..."

ASSET_IDS=$(grep -rhoE '(id|Id|ID|Asset|Sound|Model|Image|Texture)\s*=\s*[0-9]{10,}|rbxassetid://[0-9]+' src/ 2>/dev/null \
    | grep -oE '[0-9]{10,}' \
    | sort -u)

if [ -z "$ASSET_IDS" ]; then
    echo "No asset IDs found in src/"
    exit 0
fi

ASSET_COUNT=$(echo "$ASSET_IDS" | wc -l)

echo ""
echo "=== Roblox Asset Permissions Grant ==="
echo ""
echo "Universe ID: $ROBLOX_UNIVERSE_ID"
echo "Assets found: $ASSET_COUNT"
echo ""
echo "Asset IDs:"
if [ "$ASSET_COUNT" -le 20 ]; then
    echo "$ASSET_IDS"
else
    echo "$ASSET_IDS" | head -10
    echo "... and $((ASSET_COUNT - 10)) more"
fi
echo ""

REQUEST_BODY=$(cat <<EOF
{
  "subjectType": "Universe",
  "subjectId": "$ROBLOX_UNIVERSE_ID",
  "action": "Use",
  "requests": [
$(echo "$ASSET_IDS" | while read id; do
    echo "    {\"assetId\": $id},"
done | sed '$ s/,$//')
  ]
}
EOF
)

echo "Sending request to Roblox Asset Permissions API..."
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X PATCH \
    "https://apis.roblox.com/asset-permissions-api/v1/assets/permissions" \
    -H "x-api-key: $ROBLOX_OPEN_CLOUD_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Success!"
    echo ""
    
    SUCCESS_COUNT=$(echo "$BODY" | jq -r '.successAssetIds | length' 2>/dev/null || echo "unknown")
    ERROR_COUNT=$(echo "$BODY" | jq -r '.errors | length' 2>/dev/null || echo "0")
    
    echo "Summary:"
    echo "  - Successfully granted: $SUCCESS_COUNT assets"
    echo "  - Errors: $ERROR_COUNT"
    
    if [ "$ERROR_COUNT" != "0" ] && [ "$ERROR_COUNT" != "null" ]; then
        echo ""
        echo "Errors (assets you don't own or don't exist):"
        echo "$BODY" | jq -r '.errors[]? | "  - Asset \(.assetId): \(.code)"' 2>/dev/null
    fi
else
    echo "❌ Failed!"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
    
    if [ "$HTTP_CODE" = "403" ]; then
        echo ""
        echo "Permission denied. Make sure your API key has:"
        echo "  1. 'asset-permissions' in Access Permissions"
        echo "  2. 'Write' operation enabled"
        echo "  3. Access to the assets (you must own them)"
    elif [ "$HTTP_CODE" = "400" ]; then
        echo ""
        echo "Bad request. Check that:"
        echo "  1. Universe ID is correct"
        echo "  2. Asset IDs are valid"
    fi
    
    exit 1
fi
