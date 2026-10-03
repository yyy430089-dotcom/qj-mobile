"""在可用的 iPhone 模拟器启动主应用并截图；不冒充真机键盘测试。"""
import argparse
import json
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent


def simctl(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True, cwd=ROOT)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bootstrap', action='store_true')
    args = parser.parse_args()
    devices = json.loads(simctl('list', 'devices', 'available', '-j'))['devices']
    candidates = [d for runtime, group in devices.items() if 'iOS' in runtime for d in group if 'iPhone' in d['name']]
    if not candidates:
        raise RuntimeError('No iPhone simulator runtime installed')
    device = candidates[0]
    udid = device['udid']
    if device['state'] != 'Booted':
        simctl('boot', udid)
    simctl('bootstatus', udid, '-b')
    app = ROOT / 'build/DerivedData/Build/Products/Release-iphonesimulator/QJMobile.app'
    simctl('install', udid, str(app))
    launched = simctl('launch', udid, 'app.qjmobile.personal')
    time.sleep(3)
    simctl('io', udid, 'screenshot', str(ROOT / 'build/app-screenshot.png'))
    if not args.bootstrap:
        subprocess.run(['xcodebuild', '-project', 'QJMobile.xcodeproj', '-scheme', 'QJMobileTests',
                        '-configuration', 'Release', '-sdk', 'iphonesimulator',
                        '-destination', f'platform=iOS Simulator,id={udid}',
                        '-derivedDataPath', 'build/DerivedData', '-resultBundlePath', 'build/SwiftTests.xcresult',
                        '-parallel-testing-enabled', 'NO', '-test-timeouts-enabled', 'YES',
                        '-default-test-execution-time-allowance', '30',
                        '-maximum-test-execution-time-allowance', '45',
                        'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'ARCHS=arm64', 'test'],
                       cwd=ROOT, check=True, timeout=360)
        subprocess.run(['ditto', '-c', '-k', '--keepParent', 'build/SwiftTests.xcresult',
                        'build/swift-tests.xcresult.zip'], cwd=ROOT, check=True)
        subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', 'build/SwiftTests.xcresult',
                        '--output-path', 'build/screenshots'], cwd=ROOT, check=True)
    result = {'device': device['name'], 'launch': launched.strip(), 'host_app_launch': 'passed',
              'swift_bridge_tests': 'skipped bootstrap' if args.bootstrap else 'passed',
              'keyboard_layout_tests': 'skipped bootstrap' if args.bootstrap else 'passed (portrait, landscape, dark mode)',
              'keyboard_enable_and_cross_app_typing': 'pending physical device validation'}
    (ROOT / 'build/simulator-report.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
