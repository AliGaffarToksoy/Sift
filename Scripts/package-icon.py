"""Package the generated PNG representations in an ICNS container."""
import struct
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
representations = {
    'icp4': 'icon_16x16.png', 'ic11': 'icon_16x16@2x.png',
    'icp5': 'icon_32x32.png', 'ic12': 'icon_32x32@2x.png',
    'ic07': 'icon_128x128.png', 'ic13': 'icon_128x128@2x.png',
    'ic08': 'icon_256x256.png', 'ic14': 'icon_256x256@2x.png',
    'ic09': 'icon_512x512.png', 'ic10': 'icon_512x512@2x.png',
}
chunks = []
for kind, filename in representations.items():
    png = (source / filename).read_bytes()
    assert png.startswith(b'\x89PNG\r\n\x1a\n'), filename
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(png) + 8) + png)
payload = b''.join(chunks)
destination.write_bytes(b'icns' + struct.pack('>I', len(payload) + 8) + payload)
