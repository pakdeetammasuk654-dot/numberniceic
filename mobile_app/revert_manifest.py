
import os

manifest_path = 'android/app/src/main/AndroidManifest.xml'

with open(manifest_path, 'r') as f:
    content = f.read()

# Remove the inserted LINE configuration
start_marker = '<!-- LINE Login Configuration -->'
end_marker = '</application>'

if start_marker in content:
    # Find the start index
    start_idx = content.find(start_marker)
    # Find the closing </application> tag strictly after the start marker
    # But wait, I inserted it just before the last </application>.
    # So I can just split and reconstruct.
    
    # Simpler approach: Remove the specific string block I added.
    # But strings in python multiline are tricky with indentation.
    
    # Let's try to remove everything between start_marker and the LAST </activity> tag inside that block.
    # Or better, just restore the backup if I had one. I don't.
    
    # I will replace standard known block.
    line_config_content = '''
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
    # Normalize whitespace/newlines potentially
    # This is risky. Let's try reading line by line and filtering.
    
    lines = content.splitlines()
    new_lines = []
    skip = False
    for line in lines:
        if '<!-- LINE Login Configuration -->' in line:
            skip = True
        
        if not skip:
            new_lines.append(line)
            
        if skip and '</activity>' in line and 'intent-filter' in content[content.find(line)-200:content.find(line)+200]: 
             # Rough heuristic. Actually, the block ends with </activity>. 
             # But there are two </activity>.
             pass

    # Actually, the block I added is quite specific. I can just search and replace it with blank.
    # But exact whitespace matching might fail.
    
    # Alternate Plan: Read file, find start_marker, find the application closing tag, remove text in between.
    
    idx_start = content.find(start_marker)
    if idx_start != -1:
        # Assuming the inserted block ends before the closing </application> tag
        # And I know I inserted it right before it.
        idx_end = content.rfind('</application>')
        
        # Check if the content between idx_start and idx_end looks like what I added.
        # It's better to just cut it out.
        
        new_content = content[:idx_start] + content[idx_end:]
        with open(manifest_path, 'w') as f:
            f.write(new_content)
        print("Reverted Manifest changes.")
    else:
        print("Marker not found.")

else:
    print("LINE Config marker not found.")
