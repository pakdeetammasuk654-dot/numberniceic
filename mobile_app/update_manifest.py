
import os

manifest_path = 'android/app/src/main/AndroidManifest.xml'
line_config = '''
        <!-- LINE Login Configuration -->
        <activity
            android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:exported="false"
            android:launchMode="singleTop"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar">
        </activity>
        <activity
            android:name="com.linecorp.linesdk.auth.internal.LineAuthenticationCallbackActivity"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/Theme.AppCompat.Light.NoActionBar">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="line3rdp.com.taya.numberniceic" />
            </intent-filter>
        </activity>
'''

with open(manifest_path, 'r') as f:
    content = f.read()

if 'line3rdp.com.taya.numberniceic' not in content:
    # Insert before the closing </application> tag
    new_content = content.replace('</application>', line_config + '\n    </application>')
    
    with open(manifest_path, 'w') as f:
        f.write(new_content)
    print("Updates Manifest configuration for LINE successfully.")
else:
    print("Manifest already contains LINE configuration.")
