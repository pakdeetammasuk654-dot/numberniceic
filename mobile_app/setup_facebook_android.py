
import os

def setup_facebook_android():
    base_dir = '/Users/tayap/apps-go/numberniceic/mobile_app/android/app/src/main'
    res_dir = os.path.join(base_dir, 'res/values')
    manifest_path = os.path.join(base_dir, 'AndroidManifest.xml')
    strings_path = os.path.join(res_dir, 'strings.xml')

    # 1. Create/Update strings.xml
    if not os.path.exists(res_dir):
        os.makedirs(res_dir)
    
    strings_content = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">NumberNice</string>
    <string name="facebook_app_id">1564787444833363</string>
    <string name="fb_login_protocol_scheme">fb1564787444833363</string>
    <string name="facebook_client_token">234ca1ad879a87df5d967cbf773f961d</string>
</resources>
"""
    with open(strings_path, 'w') as f:
        f.write(strings_content)
    print(f"✅ Created {strings_path}")

    # 2. Update AndroidManifest.xml
    with open(manifest_path, 'r') as f:
        manifest = f.read()

    # Check if already added
    if 'com.facebook.sdk.ApplicationId' in manifest:
        print("⚠️ Facebook config already exists in Manifest.")
        # But we force update just in case it's incomplete? No, let's trust it or user manual check.
        # Actually, let's check if the specific App ID is there.
        if '1564787444833363' in manifest:
             print("✅ Facebook App ID seems correct in Manifest.")
        else:
             print("⚠️ Facebook might be configured with WRONG App ID in Manifest!")
    else:
        # Inject config inside <application>
        facebook_config = """
        <meta-data android:name="com.facebook.sdk.ApplicationId" android:value="@string/facebook_app_id"/>
        <meta-data android:name="com.facebook.sdk.ClientToken" android:value="@string/facebook_client_token"/>
        
        <activity android:name="com.facebook.FacebookActivity"
            android:configChanges=
                "keyboard|keyboardHidden|screenLayout|screenSize|orientation"
            android:label="@string/app_name" />
            
        <activity
            android:name="com.facebook.CustomTabActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="@string/fb_login_protocol_scheme" />
            </intent-filter>
        </activity>
        """
        
        # Insert before </application>
        if '</application>' in manifest:
            new_manifest = manifest.replace('</application>', facebook_config + '\n    </application>')
            with open(manifest_path, 'w') as f:
                f.write(new_manifest)
            print("✅ Injected Facebook config into AndroidManifest.xml")
        else:
            print("❌ Copuld not find </application> tag in Manifest!")

    # 3. Add Queries (if not exists)
    # Check if <queries> tag exists
    if '<queries>' not in manifest:
        # Insert queries block
        queries_block = """
    <queries>
        <provider android:authorities="com.facebook.katana.provider.PlatformProvider" />
        <package android:name="com.facebook.katana" />
    </queries>
"""
        # Insert before <application>
        if '<application' in manifest:
            # Note: This is a simple replace, might be fragile if multiple matches, but usually only one <application
            new_manifest = manifest.replace('<application', queries_block + '\n    <application')
            # Write again (might overwrite previous write, so re-read or carefully chain)
            # Re-read to be safe
            with open(manifest_path, 'r') as f:
                current_manifest = f.read()
            
            final_manifest = current_manifest.replace('<application', queries_block + '\n    <application')
            
            with open(manifest_path, 'w') as f:
                f.write(final_manifest)
            print("✅ Injected <queries> into AndroidManifest.xml")

if __name__ == "__main__":
    setup_facebook_android()
