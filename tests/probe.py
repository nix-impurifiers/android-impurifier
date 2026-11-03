# SPDX-License-Identifier: MIT
"""Boot the pinned Android userspace and establish its real package-manager interface."""
import os
from pathlib import Path
import shlex
import runpy
import socket
import subprocess
import sys
import time

image, iso = map(Path, sys.argv[1:3])
def unused_port():
    with socket.socket() as reservation:
        reservation.bind(('127.0.0.1', 0))
        return reservation.getsockname()[1]

# Builders may share networking: each guest and ADB server needs its own ports.
server_port = unused_port()
guest_port = unused_port()
endpoint = f'127.0.0.1:{guest_port}'
os.environ['ADB_SERVER_SOCKET'] = f'tcp:{server_port}'
print(f'Private ADB server {server_port}; guest endpoint {endpoint}', flush=True)
serial = Path('android-console.log')
android_log = Path('android-logcat.log')
collector = None
collector_stream = None
with serial.open('wb') as log:
    guest = subprocess.Popen([
        'qemu-system-x86_64', '-machine', 'accel=tcg', '-cpu', 'qemu64,+ssse3,+sse4.1,+sse4.2,+popcnt', '-m', '4096', '-smp', '4',
        '-object', 'rng-random,id=rng,filename=/dev/urandom', '-device', 'virtio-rng-pci,rng=rng',
        '-display', 'none', '-vga', 'std', '-no-reboot', '-serial', 'stdio',
        '-kernel', str(image / 'kernel'), '-initrd', str(image / 'initrd.img'),
        '-cdrom', str(iso),
        '-append', 'root=/dev/ram0 SRC= DATA= SETUPWIZARD=0 nomodeset vga=834 HWACCEL=0 VIRT_WIFI=0 console=ttyS0 androidboot.hardware=android_x86_64',
        '-netdev', f'user,id=net,hostfwd=tcp:127.0.0.1:{guest_port}-:5555', '-device', 'e1000,netdev=net',
    ], stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT)
    def console(command):
        guest.stdin.write((command + '\n').encode())
        guest.stdin.flush()
    def configure_network():
        # Android-x86 can rename the emulated NIC; identify it by its fixed MAC.
        console('for dev in /sys/class/net/*; do if [ "$(cat "$dev/address")" = 52:54:00:12:34:56 ]; then nic=${dev##*/}; ip link set "$nic" up; ip addr replace 10.0.2.15/24 dev "$nic"; ip route replace default via 10.0.2.2 dev "$nic"; fi; done; ip rule add priority 100 lookup main')
    try:
        subprocess.run(['adb', 'start-server'], check=True, stdin=subprocess.DEVNULL, timeout=15)
        # Cold first-boot DEX compilation of the pinned upstream image is slow on CI TCG.
        deadline = time.monotonic() + 1200
        next_report = time.monotonic() + 30
        configured = False
        while time.monotonic() < deadline:
            if guest.poll() is not None:
                raise RuntimeError('Android guest exited during boot: QEMU status ' + str(guest.returncode))
            transcript = serial.read_text(errors='replace')
            if not configured and 'console:/ #' in transcript:
                key = Path(os.environ['HOME']) / '.android/adbkey.pub'
                console('stty sane -echo -iuclc -olcuc')
                # stty flushes queued terminal input; send setup only after it returns.
                time.sleep(2)
                configure_network()
                if key.exists():
                    console('mkdir -p /data/misc/adb; echo ' + shlex.quote(key.read_text().strip()) +
                            ' > /data/misc/adb/adb_keys; chmod 640 /data/misc/adb/adb_keys; restorecon /data/misc/adb/adb_keys')
                console('echo 7 > /proc/sys/kernel/printk; setprop service.adb.tcp.port 5555; stop adbd; start adbd')
                configured = True
            if time.monotonic() >= next_report:
                configure_network()
                console('echo ANDROID_STATUS; ip addr; ip rule; ss -ltn; getprop service.adb.tcp.port; getprop sys.boot_completed; getprop init.svc.zygote; getprop init.svc.zygote64; getprop vold.decrypt; cat /proc/sys/kernel/random/entropy_avail; getprop init.svc.adbd; ps -A | grep -E "zygote|system_server|adbd"; logcat -b main -b system -b crash -d -t 40')
                print('Waiting for Android framework; serial tail:', transcript[-12000:], flush=True)
                if android_log.exists():
                    messages = android_log.read_text(errors='replace')
                    print('Android userspace tail:', messages[-8000:], flush=True)
                    if '>>> /system/bin/surfaceflinger <<<' in messages:
                        raise RuntimeError('Android SurfaceFlinger crashed during boot')
                next_report = time.monotonic() + 30
            try:
                subprocess.run(['adb', 'connect', endpoint], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
                status = subprocess.run(['adb', '-s', endpoint, 'shell', 'getprop', 'sys.boot_completed'],
                                        stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=5)
            except subprocess.TimeoutExpired:
                continue
            if status.returncode == 0 and collector is None:
                collector_stream = android_log.open('wb')
                collector = subprocess.Popen(['adb', '-s', endpoint, 'logcat', '-b', 'all', '-v', 'threadtime'], stdout=collector_stream, stderr=subprocess.STDOUT)
            if status.returncode == 0 and status.stdout.strip() == '1':
                print('Android framework booted', flush=True)
                ready = subprocess.run(['adb', '-s', endpoint, 'shell', 'service', 'check', 'package'], check=True, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
                assert 'found' in ready.stdout and 'not found' not in ready.stdout, ready
                if len(sys.argv) > 3:
                    def adb(*arguments, check=True, timeout=120):
                        print('ADB operation:', arguments[:3], flush=True)
                        if arguments and arguments[0] == 'shell':
                            arguments = ('shell', shlex.join(arguments[1:]))
                        return subprocess.run(['adb', '-s', endpoint, *arguments], check=check, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=timeout)
                    # The offline fixture cannot query its preinstalled cloud scanner.
                    # Package-manager certificate and APK integrity checks remain enabled.
                    adb('shell', 'settings', 'put', 'global', 'verifier_verify_adb_installs', '0')
                    assert adb('shell', 'settings', 'get', 'global', 'verifier_verify_adb_installs').stdout.strip() == '0'
                    adb('shell', 'settings', 'put', 'global', 'device_provisioned', '1')
                    adb('shell', 'settings', 'put', 'secure', 'user_setup_complete', '1')
                    adb('shell', 'wm', 'dismiss-keyguard')
                    runpy.run_path(sys.argv[3], init_globals={'adb': adb})
                break
            if status.returncode:
                print('ADB status:', status.stderr.strip(), flush=True)
                subprocess.run(['adb', 'disconnect', endpoint], capture_output=True, timeout=5)
            if guest.poll() is not None:
                raise RuntimeError('Android guest exited before framework readiness')
            time.sleep(2)
        else:
            raise RuntimeError('Android framework did not become ready')
    except BaseException:
        for diagnostic in [['shell', 'df', '-h'], ['shell', 'cat', '/proc/meminfo'], ['logcat', '-b', 'crash', '-b', 'system', '-d', '-t', '150']]:
            try:
                report = subprocess.run(['adb', '-s', endpoint, *diagnostic], stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10)
                print('Android failure diagnostics:', diagnostic, report.stdout, report.stderr, flush=True)
            except subprocess.TimeoutExpired:
                pass
        print('QEMU status:', guest.poll(), flush=True)
        if android_log.exists():
            print('Continuous Android log:', android_log.read_text(errors='replace')[-24000:], flush=True)
        raise
    finally:
        if collector is not None:
            collector.terminate()
            collector.wait(timeout=10)
            collector_stream.close()
        guest.terminate()
        try:
            guest.wait(timeout=10)
        except subprocess.TimeoutExpired:
            guest.kill()
            guest.wait()
        subprocess.run(['adb', 'kill-server'], check=False, timeout=10)
        print(serial.read_text(errors='replace')[-24000:])
