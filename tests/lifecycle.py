# SPDX-License-Identifier: MIT
"""Exercise Android's package manager, app sandbox, JNI loading and signature policy."""
import os
import time

package = 'org.niximpurifiers.proof'
for name in ['one', 'two', 'wrong', 'damaged']:
    adb('push', os.environ[name.upper() + '_APK'], '/data/local/tmp/' + name + '.apk')

def install(name, success=True):
    result = adb('shell', 'pm', 'install', '-r', '/data/local/tmp/' + name + '.apk', check=False)
    if success:
        assert result.returncode == 0 and 'Success' in result.stdout, result
    else:
        assert 'Failure' in result.stdout + result.stderr, result
    return result.stdout + result.stderr

def run(revision):
    adb('shell', 'am', 'force-stop', package)
    adb('logcat', '-c')
    started = adb('shell', 'am', 'start', '-W', '-n', package + '/org.niximpurifiers.Proof')
    assert 'Error:' not in started.stdout + started.stderr, started
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        output = adb('logcat', '-d', '-s', 'ImpurifierProof:I', '*:S').stdout
        if any(line.rstrip().endswith(': ' + revision) for line in output.splitlines()):
            return
        time.sleep(1)
    raise AssertionError('Android did not execute the JNI payload: ' + output)

install('one')
run('1')
adb('shell', 'run-as', package, 'sh', '-c', 'mkdir -p files; echo preserved > files/state')
install('two')
run('2')
assert 'preserved' in adb('shell', 'run-as', package, 'cat', 'files/state').stdout
assert 'UPDATE_INCOMPATIBLE' in install('wrong', success=False)
run('2')
install('damaged', success=False)
run('2')
adb('shell', 'test', '!', '-e', '/nix')
adb('shell', 'pm', 'uninstall', package)
assert not adb('shell', 'pm', 'path', package, check=False).stdout.strip()
adb('shell', 'test', '!', '-e', '/data/data/' + package)
print('ANDROID_PACKAGE_LIFECYCLE_OK', flush=True)
