
import os
import re

manifest_path = "android/app/src/main/AndroidManifest.xml"

with open(manifest_path, "r") as f:
    content = f.read()

# Pattern to remove manual LINE activities
# We match from <!-- LINE Login Activities --> to the closing </activity> of the second activity
# This is a bit rough, so we'll use string replacement for specific blocks we know we added.

# Block 1: LineAuthenticationActivity
content = re.sub(r'<activity[^>]*com\.linecorp\.linesdk\.auth\.internal\.LineAuthenticationActivity[^>]*>.*?</activity>', '', content, flags=re.DOTALL)

# Block 2: LineAuthenticationCallbackActivity
content = re.sub(r'<activity[^>]*com\.linecorp\.linesdk\.auth\.internal\.LineAuthenticationCallbackActivity[^>]*>.*?</activity>', '', content, flags=re.DOTALL)

# Clean up empty lines or comments
content = content.replace('<!-- LINE Login Activities (Forced Override) -->', '')

with open(manifest_path, "w") as f:
    f.write(content)

print("Cleaned MANUALLY injected LINE Activities from Manifest.")
