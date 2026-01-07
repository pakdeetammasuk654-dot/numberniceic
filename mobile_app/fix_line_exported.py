
import os

manifest_path = "android/app/src/main/AndroidManifest.xml"

with open(manifest_path, "r") as f:
    content = f.read()

# Change exported="false" to exported="true" for LineAuthenticationActivity
# And make sure LineAuthenticationCallbackActivity is correct
if 'android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationActivity"' in content:
    content = content.replace('android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationActivity"\n            android:configChanges="orientation|screenSize|keyboardHidden"\n            android:exported="false"',
                              'android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationActivity"\n            android:configChanges="orientation|screenSize|keyboardHidden"\n            android:exported="true"')

with open(manifest_path, "w") as f:
    f.write(content)

print("Fixed Manifest exported=true")
