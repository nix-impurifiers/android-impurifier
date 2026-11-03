# SPDX-License-Identifier: MIT
"""Assemble a deterministic, aligned unsigned APK from native Android inputs."""
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import zipfile

base, configuration, output = map(Path, sys.argv[1:])
spec = json.loads(configuration.read_text())
with zipfile.ZipFile(base) as archive:
    entries = {name: archive.read(name) for name in archive.namelist() if not name.endswith('/')}
for index, path in enumerate(spec['dexFiles'], 1):
    data = Path(path).read_bytes()
    if not data.startswith(b'dex\n'):
        raise ValueError('dexFiles must contain native Dalvik bytecode')
    entries['classes' + (str(index) if index > 1 else '') + '.dex'] = data
machines = {'x86': (1, 3), 'x86_64': (2, 62), 'armeabi-v7a': (1, 40), 'arm64-v8a': (2, 183)}
for abi, libraries in spec['nativeLibraries'].items():
    for name, source in libraries.items():
        if not re.fullmatch(r'lib[A-Za-z0-9_.+-]+\.so', name):
            raise ValueError('invalid Android native library filename')
        data = Path(source).read_bytes()
        if len(data) < 20 or data[:4] != b'\x7fELF' or data[5] != 1:
            raise ValueError('nativeLibraries requires little-endian ELF shared libraries')
        if struct.unpack_from('<H', data, 16)[0] != 3:
            raise ValueError('nativeLibraries requires ELF ET_DYN shared libraries')
        if (data[4], struct.unpack_from('<H', data, 18)[0]) != machines[abi]:
            raise ValueError('native library does not match requested Android ABI: ' + abi)
        entries[f'lib/{abi}/{name}'] = data
if spec['assets']:
    root = Path(spec['assets'])
    for entry in sorted(root.rglob('*')):
        if entry.is_file():
            entries['assets/' + entry.relative_to(root).as_posix()] = entry.read_bytes()
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_STORED, allowZip64=False) as archive:
    for name, data in sorted(entries.items()):
        path = PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or '\\' in name:
            raise ValueError('unsafe APK entry path')
        info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        info.external_attr = 0o100644 << 16
        alignment = 16384 if name.startswith('lib/') and name.endswith('.so') else 4
        offset = archive.fp.tell() + 30 + len(name.encode('utf8'))
        padding = (-offset) % alignment
        if 0 < padding < 4:
            padding += alignment
        if padding:
            info.extra = struct.pack('<HH', 0xFFFF, padding - 4) + bytes(padding - 4)
        archive.writestr(info, data)
