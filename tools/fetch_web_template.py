"""Fetch only matching web templates from the official release's large ZIP."""
import io
import pathlib
import struct
import urllib.request
import zipfile

URL = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
SIZE = 1281349702
DEST = pathlib.Path(__file__).resolve().parents[1] / ".tools" / "web-templates"


def read_range(start, end):
    request = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{end}", "User-Agent": "Wildbound-export-setup"})
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 206:
            raise RuntimeError("Server did not support a partial download; no full archive was downloaded")
        if response.headers.get("Content-Range") != f"bytes {start}-{end}/{SIZE}":
            raise RuntimeError("Unexpected content range")
        result = response.read(end - start + 2)
        if len(result) != end - start + 1:
            raise RuntimeError("Incomplete range")
        return result


tail = read_range(SIZE - 65557, SIZE - 1)
eocd = tail.rfind(b"PK\x05\x06")
if eocd < 0:
    raise RuntimeError("ZIP directory not found")
directory_size, directory_offset = struct.unpack_from("<II", tail, eocd + 12)
directory = read_range(directory_offset, directory_offset + directory_size - 1)
DEST.mkdir(parents=True, exist_ok=True)
cursor = 0
while cursor < len(directory):
    if directory[cursor:cursor + 4] != b"PK\x01\x02":
        raise RuntimeError("Invalid central directory")
    compressed = struct.unpack_from("<I", directory, cursor + 20)[0]
    name_len, extra_len, comment_len = struct.unpack_from("<HHH", directory, cursor + 28)
    local_offset = struct.unpack_from("<I", directory, cursor + 42)[0]
    name = directory[cursor + 46:cursor + 46 + name_len].decode("utf-8")
    entry = directory[cursor:cursor + 46 + name_len + extra_len + comment_len]
    cursor += len(entry)
    if "web" not in name.lower():
        continue
    print(f"Template: {name}, compressed bytes: {compressed}", flush=True)
    if name.split("/")[-1] != "web_nothreads_release.zip":
        continue
    header = read_range(local_offset, local_offset + 29)
    local_name_len, local_extra_len = struct.unpack_from("<HH", header, 26)
    local_size = 30 + local_name_len + local_extra_len + compressed
    local = read_range(local_offset, local_offset + local_size - 1)
    central = bytearray(entry)
    struct.pack_into("<I", central, 42, 0)
    end = struct.pack("<4sHHHHIIH", b"PK\x05\x06", 0, 0, 1, 1, len(central), len(local), 0)
    with zipfile.ZipFile(io.BytesIO(local + central + end)) as archive:
        payload = archive.read(name)  # Verifies the official ZIP entry's CRC.
    output = DEST / "web_nothreads_release.zip"
    output.write_bytes(payload)
    print(f"Saved {output.name}: {len(payload)} bytes", flush=True)
