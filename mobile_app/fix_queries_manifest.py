
import os

manifest_path = 'android/app/src/main/AndroidManifest.xml'

with open(manifest_path, 'r') as f:
    content = f.read()

# Add LINE package to queries
if '<package android:name="jp.naver.line.android" />' not in content:
    # Look for existing <queries> tag
    if '<queries>' in content:
        new_content = content.replace('<queries>', '<queries>\n        <package android:name="jp.naver.line.android" />')
    else:
        # If no queries tag exists (unlikely in Flutter), add it before </manifest>
        queries_block = '''
    <queries>
        <package android:name="jp.naver.line.android" />
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
'''
        new_content = content.replace('</manifest>', queries_block + '\n</manifest>')
        
        # If we added a full block, we might have duplicated the existing partial queries block if our search failed.
        # But in the cat output, I saw existing queries.
        
    with open(manifest_path, 'w') as f:
        f.write(new_content)
    print("Added LINE package to queries in Manifest.")
else:
    print("LINE package query already exists.")
