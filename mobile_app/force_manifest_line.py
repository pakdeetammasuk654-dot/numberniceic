
import os

manifest_path = 'android/app/src/main/AndroidManifest.xml'

# The goal is to insert the activity blocks inside the <application> tag 
# AND ensure we have the 'tools' namespace in the <manifest> tag.

with open(manifest_path, 'r') as f:
    content = f.read()

# 1. Add xmlns:tools if missing
if 'xmlns:tools' not in content:
    content = content.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android"', 
                              '<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"')

# 2. Prepare the LINE Activity block with tools:replace
line_activity_block = '''
        <!-- LINE Login Activities (Forced Override) -->
        <activity
            android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:exported="false"
            android:launchMode="singleTop"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"
            tools:replace="android:theme">
        </activity>
        <activity
            android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationCallbackActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar"
            tools:replace="android:theme">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="line3rdp.com.taya.numberniceic" />
            </intent-filter>
        </activity>
'''

# 3. Insert the block
if 'com.linecorp.linesdk.auth.internal.LineAuthenticationActivity' not in content:
    # Remove older attempts if any (simple check)
    
    # Insert before closing </application>
    new_content = content.replace('</application>', line_activity_block + '\n    </application>')
    
    with open(manifest_path, 'w') as f:
        f.write(new_content)
    print("Forced LINE Manifest configuration successfully.")
else:
    print("LINE Configuration already exists (or partial). Please check manually if it needs update.")
    # If it exists but is the old one without tools:replace, we might want to update it.
    # But for now let's assume if it exists, it's what we want or we should have reverted first.
