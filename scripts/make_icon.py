"""Deterministic opaque app icon: a cyan screen and play triangle, no dependencies."""
from pathlib import Path
import json
import struct
import zlib

root = Path(__file__).resolve().parents[1] / 'ios/App/Assets.xcassets'
folder = root / 'AppIcon.appiconset'; folder.mkdir(parents=True, exist_ok=True)
size = 1024
raw = bytearray()
for y in range(size):
    raw.append(0)
    for x in range(size):
        color = (12, 20, 34)
        if 160 <= x <= 864 and 235 <= y <= 745:
            if x < 188 or x > 836 or y < 263 or y > 717: color = (79, 215, 232)
        if 424 <= x <= 650 and abs(y - 490) <= (650 - x) * .72: color = (229, 247, 250)
        if 370 <= x <= 654 and 795 <= y <= 817: color = (79, 215, 232)
        raw.extend(color)
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
(folder/'AppIcon.png').write_bytes(png)
(folder/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}], 'info':{'author':'xcode','version':1}}, indent=2) + '\n')
(root/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
