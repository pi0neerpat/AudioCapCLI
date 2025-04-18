#!/bin/bash
set -e

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

# Configuration
BINARY_NAME="AudioCapCLI"
DIST_DIR="dist"
BUNDLE_ID="com.pi0neerpat.AudioCapCLI"

# Check for required environment variables
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_ID_PASSWORD" ] || [ -z "$APPLE_TEAM_ID" ]; then
  echo "Error: Missing required environment variables: APPLE_ID, APPLE_ID_PASSWORD, APPLE_TEAM_ID"
  echo "Please set these in your .env file or export them before running this script."
  exit 1
fi

if [ -z "$APPLE_IDENTITY" ]; then
    echo "Error: No signing identity provided."
    exit 1
fi

# Check if the app exists
if [ ! -f "./$DIST_DIR/$BINARY_NAME" ]; then
    echo "Error: $DIST_DIR/$BINARY_NAME not found in the current directory."
    exit 1
fi

echo "Step 1: Signing $BINARY_NAME with identity '$APPLE_IDENTITY'..."
codesign --force --options runtime --sign "$APPLE_IDENTITY" "./$DIST_DIR/$BINARY_NAME"
echo "Signing complete."

echo "Step 2: Creating ZIP archive for notarization..."
# Move to the dist directory to create a clean zip
cd "$DIST_DIR"
ditto -c -k --keepParent "$BINARY_NAME" "${BINARY_NAME}.zip"
echo "ZIP archive created: ${BINARY_NAME}.zip"

echo "Step 3: Submitting for notarization..."
xcrun notarytool submit "${BINARY_NAME}.zip" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_ID_PASSWORD" \
    --wait
echo "Notarization submission complete."

# For command-line tools, we don't need to staple as they aren't app bundles
echo "Note: Skipping stapling as this is a command-line tool, not an app bundle."
echo "The notarization information will be checked by Gatekeeper when the tool is run."

echo "Step 4: Verifying code signature..."
codesign -vvv --deep --strict "$BINARY_NAME"

echo "Step 5: Cleaning up..."
rm "${BINARY_NAME}.zip"
echo "Deleted temporary zip file."

echo "All done! Your application has been signed and notarized."
echo "The notarized binary is ready for distribution: $BINARY_NAME"

exit 0 