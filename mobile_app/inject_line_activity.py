
import os

# Path to AndroidManifest.xml
manifest_path = "android/app/src/main/AndroidManifest.xml"

# Activity definition to inject
line_activity = """
        <!-- Forced LINE SDK Activity Injection -->
        <activity
            android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"
            tools:replace="android:theme" />
        
        <activity
            android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationWebActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"
            tools:replace="android:theme" />
"""

# Read existing manifest
with open(manifest_path, "r") as f:
    content = f.read()

# Check if 'xmlns:tools' is present, if not add it
if "xmlns:tools" not in content:
    content = content.replace('<manifest package="com.taya.numberniceic" xmlns:android="http://schemas.android.com/apk/res/android"',
                              '<manifest package="com.taya.numberniceic" xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"')

# Inject activity before </application>
if "com.linecorp.linesdk.auth.internal.LineAuthenticationActivity" not in content:
    content = content.replace("    </application>", line_activity + "\n    </application>")
    
    with open(manifest_path, "w") as f:
        f.write(content)
    print("Injected LINE Activity to Manifest.")
else:
    print("LINE Activity already exists in Manifest.")
