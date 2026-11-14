#!/usr/bin/env python3
"""Build and independently verify the project's arm64 Android debug APK."""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile
import xml.etree.ElementTree as ET


PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path('/Applications/Godot.app/Contents/MacOS/Godot')
CONTROLLER = '/Users/junming/AI-Setup/storage/storagectl.py'
VERSION = '0.9.0'
VERSION_CODE = 9


def run(args, env=None):
    return subprocess.run([str(a) for a in args], cwd=PROJECT, env=env, check=True)


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def text(value):
    """Godot strings share the JSON escapes needed for these filesystem paths."""
    return json.dumps(str(value), ensure_ascii=False)


def configure_editor(java, sdk, key):
    # Preserve other settings, and save just these non-secret prior paths once.
    settings = Path.home() / 'Library/Application Support/Godot/editor_settings-4.7.tres'
    content = settings.read_text()
    original = content
    changes = {
        'export/android/java_sdk_path': java,
        'export/android/android_sdk_path': sdk,
        'export/android/debug_keystore': key,
    }
    previous = {}
    for name, value in changes.items():
        pattern = r'^' + re.escape(name) + r' = (.*)$'
        match = re.search(pattern, content, re.M)
        previous[name] = match.group(1) if match else None
        replacement = name + ' = ' + text(value)
        if match:
            content = re.sub(pattern, lambda _: replacement, content, flags=re.M)
        else:
            content += '\n' + replacement + '\n'
    notice = PROJECT / 'tools/android-editor-settings-before.json'
    if not notice.exists():
        notice.write_text(json.dumps(previous, indent=2) + '\n')
    if content != original:
        settings.write_text(content)


def main():
    prerequisites = json.loads((PROJECT / 'tools/android-prerequisites.json').read_text())
    if not prerequisites.get('android_sdk_license_accepted') or not prerequisites.get('android_sdk_installed'):
        raise SystemExit('SDK installation/license confirmation is incomplete. No automatic acceptance is performed.')
    root = Path(subprocess.check_output([
        'python3', '-B', CONTROLLER, 'path', 'artifacts', '--project',
        'codex/RPG_Game_Dev', '--mkdir'], text=True).strip())
    java = Path(prerequisites['jdk']['java_home'])
    sdk = Path(prerequisites['sdk_root'])
    templates = Path(prerequisites['templates']['directory'])
    for path in (java, sdk, templates):
        path.relative_to(root)  # All bulk tool paths must belong to this checked SSD project.
    debug_template = templates / 'android_debug.apk'
    expected = prerequisites['templates']['extracted_files']['android_debug.apk']['sha256']
    if sha256(debug_template) != expected:
        raise SystemExit('The verified Android template has changed.')
    apksigner = sdk / 'build-tools/36.1.0/apksigner'
    if not apksigner.exists() or not (sdk / 'platform-tools/adb').exists():
        raise SystemExit('The approved SDK packages are missing.')

    env = os.environ.copy()
    env['JAVA_HOME'] = str(java)
    env['ANDROID_HOME'] = str(sdk)
    # A project-specific DEBUG identity; private key stays on the internal disk.
    key = Path.home() / 'Library/Application Support/Bramble/keys/android-debug.keystore'
    key.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not key.exists():
        run([java / 'bin/keytool', '-genkeypair', '-keystore', key,
             '-storetype', 'JKS', '-storepass', 'android', '-keypass', 'android',
             '-alias', 'androiddebugkey', '-keyalg', 'RSA', '-keysize', '2048',
             '-validity', '10000', '-dname', 'CN=Android Debug,O=Android,C=US'], env)
        key.chmod(0o600)
    configure_editor(java, sdk, key)
    destination = root / 'builds/android'
    destination.mkdir(parents=True, exist_ok=True)
    apk = destination / 'bramble-v0.9-debug.apk'

    preset = '''[preset.0]
name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="assets/fonts/OFL.txt,assets/fonts/SOURCE.md"
exclude_filter="tests/*,tools/*"
export_path=%s
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]
custom_template/debug=%s
custom_template/release=%s
gradle_build/use_gradle_build=false
gradle_build/export_format=0
gradle_build/min_sdk=""
gradle_build/target_sdk=""
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
version/code=%s
version/name=%s
package/unique_name="org.bramble.prototype"
package/name="Bramble"
package/signed=true
screen/immersive_mode=true
permissions/internet=false
''' % (text(apk), text(debug_template), text(templates / 'android_release.apk'), VERSION_CODE, text(VERSION))
    (PROJECT / 'game/export_presets.cfg').write_text(preset)
    run([GODOT, '--headless', '--path', PROJECT / 'game', '--editor', '--import', '--quit'], env)
    run([GODOT, '--headless', '--path', PROJECT / 'game', '--export-debug', 'Android', apk], env)
    # Exporter success alone is insufficient: verify the final signature separately.
    verification = subprocess.run([str(apksigner), 'verify', '--verbose', '--print-certs', str(apk)],
                                  env=env, text=True, capture_output=True, check=True)
    with zipfile.ZipFile(apk) as archive:
        native_abis = sorted({entry.split('/')[1] for entry in archive.namelist() if entry.startswith('lib/') and entry.endswith('.so')})
        if native_abis != ['arm64-v8a']:
            raise RuntimeError('Unexpected APK architectures: ' + repr(native_abis))
        if archive.testzip() is not None:
            raise RuntimeError('APK ZIP integrity check failed.')
        if any('/tests/' in entry or 'run_tests' in entry or 'scene_flow' in entry for entry in archive.namelist()):
            raise RuntimeError('Test harness accidentally included in APK.')
        if 'assets/assets/fonts/OFL.txt' not in archive.namelist():
            raise RuntimeError('Bundled font license is missing.')
    # The vendor apkanalyzer shell launcher splits SDK paths containing spaces.
    # Invoke its official Java entry point with an argument array instead.
    cli = sdk / 'cmdline-tools/latest'
    inspection = subprocess.run([
        str(java / 'bin/java'), '-Dcom.android.sdklib.toolsdir=' + str(cli),
        '-classpath', str(cli / 'lib/apkanalyzer-classpath.jar'),
        'com.android.tools.apk.analyzer.ApkAnalyzerCli', 'manifest', 'print', str(apk)
    ], env=env, text=True, capture_output=True, check=True)
    manifest = ET.fromstring(inspection.stdout)
    ns = '{http://schemas.android.com/apk/res/android}'
    sdk_info = manifest.find('uses-sdk')
    application = manifest.find('application')
    manifest_summary = {
        'package': manifest.attrib['package'],
        'version_name': manifest.attrib.get(ns + 'versionName'),
        'version_code': manifest.attrib.get(ns + 'versionCode'),
        'minimum_sdk': sdk_info.attrib.get(ns + 'minSdkVersion'),
        'target_sdk': sdk_info.attrib.get(ns + 'targetSdkVersion'),
        'debuggable': application.attrib.get(ns + 'debuggable'),
        'permissions': [node.attrib.get(ns + 'name') for node in manifest.findall('uses-permission')],
        'orientations': [node.attrib.get(ns + 'screenOrientation') for node in application.findall('activity')],
    }
    if manifest_summary['package'] != 'org.bramble.prototype' or manifest_summary['permissions']:
        raise RuntimeError('Unexpected package identity or permissions: ' + repr(manifest_summary))
    if manifest_summary['minimum_sdk'] != '24' or manifest_summary['target_sdk'] != '36':
        raise RuntimeError('Unexpected Android SDK targets: ' + repr(manifest_summary))
    if manifest_summary['version_name'] != VERSION or manifest_summary['version_code'] != str(VERSION_CODE):
        raise RuntimeError('Unexpected APK version: ' + repr(manifest_summary))
    (PROJECT / 'docs/development/android-manifest.xml').write_text(inspection.stdout)
    receipt = {
        'path': str(apk), 'bytes': apk.stat().st_size, 'sha256': sha256(apk),
        'package': 'org.bramble.prototype', 'version': VERSION, 'build_type': 'debug',
        'architectures': native_abis, 'signature_verified': True,
        'verification_output': verification.stdout.strip(),
        'device_installed': False, 'device_tested': False,
        'debug_keystore_path': str(key),
        'manifest': manifest_summary, 'manifest_verified': True,
    }
    (PROJECT / 'tools/android-build.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(verification.stdout)
    print('Verified APK:', apk)
    print('SHA256:', receipt['sha256'])


if __name__ == '__main__':
    main()
