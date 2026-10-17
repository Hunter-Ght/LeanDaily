"""Build a local App Store IPA without requiring a registered development device.

Uses the Apple Account already signed into Xcode. Exports only; never uploads.
Run from any directory: python3 tool/build_ios_app_store.py
"""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default=shutil.which('flutter') or str(Path.home() / '.local/share/flutter/bin/flutter'))
    parser.add_argument('--team-id', help='Optional override; defaults to Runner Release signing team')
    args = parser.parse_args()
    team = args.team_id
    if not team:
        result = subprocess.check_output([
            'xcodebuild', '-showBuildSettings', '-json', '-workspace', 'ios/Runner.xcworkspace',
            '-scheme', 'Runner', '-configuration', 'Release', '-sdk', 'iphoneos',
            '-destination', 'generic/platform=iOS',
        ], cwd=root)
        runner = next(t for t in json.loads(result) if t['target'] == 'Runner')
        team = runner['buildSettings'].get('DEVELOPMENT_TEAM')
    if not team:
        raise SystemExit('Select your organization Team for Runner in Xcode first, or pass --team-id.')
    # App Store export can provision distribution assets without registering an
    # iPhone. Normal Flutter archiving first requests a development profile.
    subprocess.run([args.flutter, 'build', 'ipa', '--release', '--no-codesign'], cwd=root, check=True)
    options = root / 'build/ios/ExportOptions-AppStore.plist'
    options.write_bytes(plistlib.dumps({
        'method': 'app-store-connect', 'destination': 'export',
        'teamID': team, 'signingStyle': 'automatic',
        'manageAppVersionAndBuildNumber': False,
    }, sort_keys=False))
    subprocess.run([
        'xcodebuild', '-exportArchive', '-archivePath', 'build/ios/archive/Runner.xcarchive',
        '-exportPath', 'build/ios/ipa', '-exportOptionsPlist', str(options),
        '-allowProvisioningUpdates',
    ], cwd=root, check=True)
    for ipa in (root / 'build/ios/ipa').glob('*.ipa'):
        print(f'App Store IPA: {ipa}')


if __name__ == '__main__':
    main()
