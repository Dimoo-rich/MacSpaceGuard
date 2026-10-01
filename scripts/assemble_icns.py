#!/usr/bin/env python3
"""Assemble PNG-backed ICNS chunks when iconutil rejects a valid iconset."""

from pathlib import Path
import struct
import sys


if len(sys.argv) != 3:
    raise SystemExit("Usage: assemble_icns.py ICONSET_DIR OUTPUT.icns")

iconset = Path(sys.argv[1])
output = Path(sys.argv[2])
entries = [
    (b"icp4", "icon_16x16.png"),
    (b"ic11", "icon_16x16@2x.png"),
    (b"icp5", "icon_32x32.png"),
    (b"ic12", "icon_32x32@2x.png"),
    (b"ic07", "icon_128x128.png"),
    (b"ic13", "icon_128x128@2x.png"),
    (b"ic08", "icon_256x256.png"),
    (b"ic14", "icon_256x256@2x.png"),
    (b"ic09", "icon_512x512.png"),
    (b"ic10", "icon_512x512@2x.png"),
]

chunks = []
for chunk_type, filename in entries:
    png = (iconset / filename).read_bytes()
    if not png.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG: {filename}")
    chunks.append(struct.pack(">4sI", chunk_type, len(png) + 8) + png)

size = 8 + sum(len(chunk) for chunk in chunks)
output.write_bytes(struct.pack(">4sI", b"icns", size) + b"".join(chunks))
