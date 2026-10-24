from pathlib import Path
import struct, zlib
root=Path(__file__).resolve().parents[1]/'web'
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
for size,name in [(192,'icon-192.png'),(512,'icon-512.png'),(180,'apple-touch-icon.png')]:
    raw=bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            a,b=x/size,y/size;c=(101,221,202)
            if .23<a<.77 and .3<b<.7 and (a<.265 or a>.735 or b<.335 or b>.665):c=(18,43,42)
            if .43<a<.62 and abs(b-.5)<(.62-a)*.65:c=(18,43,42)
            if .4<a<.6 and .755<b<.785:c=(18,43,42)
            raw.extend(c)
    (root/name).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>2I5B',size,size,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))
