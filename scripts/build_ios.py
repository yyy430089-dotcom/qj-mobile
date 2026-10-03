"""在 Mac 上构建含键盘扩展的 IPA 和模拟器应用；bootstrap 验证安装外壳。"""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bootstrap', action='store_true')
    args = parser.parse_args()
    build = ROOT / 'build'
    build.mkdir(exist_ok=True)
    (build / 'Data').mkdir(exist_ok=True)
    shutil.copytree(ROOT / 'Licenses', build / 'Licenses', dirs_exist_ok=True)
    for name in ['LICENSE', 'THIRD_PARTY_NOTICES.md']:
        shutil.copy2(ROOT / name, build / 'Licenses' / name)
    spec = (ROOT / 'project.yml').read_text(encoding='utf-8')
    if args.bootstrap:
        spec = spec.replace("OTHER_LDFLAGS: ['$(inherited)', '-lqjmobile', '-lc++', '-liconv']", "OTHER_LDFLAGS: ['$(inherited)']\n        SWIFT_ACTIVE_COMPILATION_CONDITIONS: '$(inherited) BOOTSTRAP'")
    else:
        metadata = json.loads(subprocess.check_output(['cargo', 'metadata', '--locked', '--format-version', '1'], cwd=ROOT, text=True))
        dependencies = []
        for package in metadata['packages']:
            if package['source'] is None:
                continue
            dependencies.append({key: package.get(key) for key in ['name', 'version', 'license', 'repository']})
            directory = pathlib.Path(package['manifest_path']).parent
            notice_dir = build / 'Licenses/Rust' / (package['name'] + '-' + package['version'])
            for path in directory.iterdir():
                if path.is_file() and path.name.upper().startswith(('LICENSE', 'COPYING', 'NOTICE')):
                    notice_dir.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, notice_dir / path.name)
        (build / 'Licenses/RUST-DEPENDENCIES.json').write_text(json.dumps(dependencies, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        run('cargo', 'run', '--locked', '--release', '-p', 'qjmobile-bridge', '--bin', 'pack-data', '--', 'DataSource', 'build/Data')
        for target in ['aarch64-apple-ios', 'aarch64-apple-ios-sim']:
            run('rustup', 'target', 'add', target)
            run('cargo', 'build', '--locked', '--release', '-p', 'qjmobile-bridge', '--lib', '--target', target)
    # 此文件与原 spec 同目录，使 XcodeGen 的资源相对路径保持稳定。
    temp_spec = ROOT / '.project-build.yml'
    temp_spec.write_text(spec, encoding='utf-8')
    try:
        run('xcodegen', 'generate', '--spec', str(temp_spec), '--project', str(ROOT))
    finally:
        temp_spec.unlink(missing_ok=True)
    base = ['xcodebuild', '-project', 'QJMobile.xcodeproj', '-scheme', 'QJMobile',
            '-configuration', 'Release', '-derivedDataPath', 'build/DerivedData',
            'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO']
    run(*base, '-sdk', 'iphoneos', '-destination', 'generic/platform=iOS', 'build')
    device_app = build / 'DerivedData/Build/Products/Release-iphoneos/QJMobile.app'
    extension = device_app / 'PlugIns/QJKeyboard.appex'
    if not extension.exists():
        raise RuntimeError('Keyboard extension missing from device app')
    ipa = build / ('QJMobile-bootstrap.ipa' if args.bootstrap else 'QJMobile.ipa')
    with zipfile.ZipFile(ipa, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(device_app.rglob('*')):
            if path.is_file():
                archive.write(path, pathlib.Path('Payload/QJMobile.app') / path.relative_to(device_app))
    run(*base, '-sdk', 'iphonesimulator', '-destination', 'generic/platform=iOS Simulator', 'build')
    sim_app = build / 'DerivedData/Build/Products/Release-iphonesimulator/QJMobile.app'
    run('ditto', '-c', '-k', '--keepParent', str(sim_app), str(build / 'QJMobile-simulator.zip'))
    report = {
        'variant': 'bootstrap' if args.bootstrap else 'full', 'signed': False,
        'ipa': ipa.name, 'ipa_sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
        'ipa_bytes': ipa.stat().st_size, 'keyboard_extension_present': True,
        'device_build': 'passed', 'simulator_build': 'passed',
        'upstream': json.loads((ROOT / 'UPSTREAM.json').read_text(encoding='utf-8')),
        'physical_device_tests': 'pending user installation',
    }
    (build / 'build-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
