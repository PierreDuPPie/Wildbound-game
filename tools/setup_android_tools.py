"""Install isolated, checksum-verified official Android/Java export tools.

Does not change machine PATH, existing SDKs, or production signing keys.
Run sdkmanager separately after reading its license prompts.
"""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1] / ".tools" / "android-rc1"
ROOT.mkdir(parents=True, exist_ok=True)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Wildbound-Android-Setup"})
    return urllib.request.urlopen(req, timeout=120)


def install(url, checksum, name, dest):
    archive = ROOT / name
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != checksum:
        print("Downloading " + name, flush=True)
        with fetch(url) as response, archive.open("wb") as out:
            while chunk := response.read(1024 * 1024):
                out.write(chunk)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != checksum:
        raise RuntimeError("Checksum mismatch: " + name)
    with zipfile.ZipFile(archive) as z:
        for member in z.namelist():
            if not (dest / member).resolve().is_relative_to(dest.resolve()):
                raise RuntimeError("Unsafe archive path")
        # Windows' legacy MAX_PATH affects some deeply nested SDK jars.
        for member in z.infolist():
            relative = Path(member.filename)
            if name.startswith("commandlinetools-"):
                relative = relative.relative_to("cmdline-tools")
            target = (dest / relative).resolve()
            if os.name == "nt": target = Path("\\\\?\\" + str(target))
            target.parent.mkdir(parents=True, exist_ok=True)
            if member.is_dir(): target.mkdir(exist_ok=True)
            else: target.write_bytes(z.read(member))
    print("Verified and extracted " + name, flush=True)


with fetch("https://api.github.com/repos/adoptium/temurin17-binaries/releases/latest") as response:
    release = json.load(response)
asset = next(a for a in release["assets"] if a["name"].startswith("OpenJDK17U-jdk_x64_windows_hotspot_") and a["name"].endswith(".zip"))
checksum_asset = next(a for a in release["assets"] if a["name"] == asset["name"] + ".sha256.txt")
with fetch(checksum_asset["browser_download_url"]) as response:
    jdk_hash = response.read().decode().split()[0]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    jobs = [
        pool.submit(install, asset["browser_download_url"], jdk_hash, asset["name"], ROOT / "java"),
        pool.submit(install, "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip", "90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a", "commandlinetools-win-15859902_latest.zip", ROOT / "sdk" / "cmdline-tools" / "latest"),
    ]
    for job in jobs:
        job.result()
print(json.dumps({"java": str(next((ROOT / "java").glob("jdk-*"))), "sdk": str(ROOT / "sdk")}, indent=2))
