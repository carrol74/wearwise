import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess


def run(command, *, log=None):
    print("Running:", " ".join(str(value) for value in command), flush=True)
    if log is None:
        return subprocess.run(command, check=True, text=True, capture_output=True).stdout.strip()
    with log.open("w") as stream:
        subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
    return ""


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description="Test ignored local garment originals without simulator foreground extraction.")
    parser.add_argument("--materials", type=Path, default=root / "test-assets/garments")
    parser.add_argument("--looks", type=Path, help="JSON look plan for additional transparent-cutout and character checks.")
    parser.add_argument("--output", type=Path, default=root / ".tmp/garment-materials" / datetime.now().strftime("%Y%m%d-%H%M%S"))
    args = parser.parse_args()
    files = sorted(path for path in args.materials.resolve().iterdir() if path.is_file() and not path.name.startswith("."))
    if not files:
        raise ValueError("Add garment images to the materials directory before running this review.")
    unsupported = [path.name for path in files if path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp"}]
    if unsupported:
        raise ValueError(f"Unsupported material extensions: {unsupported}")
    looks = json.loads(args.looks.read_text(encoding="utf-8")) if args.looks else None
    if looks is not None:
        names = {path.name for path in files}
        for look in looks:
            if len(look["garments"]) != 3 or not set(look["garments"]).issubset(names):
                raise ValueError(f"Each look requires three existing cutout files: {look}")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    os.environ["DEVELOPER_DIR"] = "/Applications/Xcode.app/Contents/Developer"
    device = run(["xcrun", "simctl", "create", "Wearwise local garments", "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation", "com.apple.CoreSimulator.SimRuntime.iOS-18-4"])
    staged = None
    booted = False
    try:
        run(["xcrun", "simctl", "boot", device])
        booted = True
        run(["xcrun", "simctl", "bootstatus", device, "-b"], log=output / "boot.log")
        build = Path("/private/tmp/wearwise-ios-build")
        common = ["xcodebuild", "-project", str(root / "ios/Wearwise.xcodeproj"), "-scheme", "Wearwise",
                  "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={device}",
                  "-derivedDataPath", str(build), "CODE_SIGNING_ALLOWED=NO"]
        run(common + ["build-for-testing"], log=output / "build.log")
        destination = build / "Build/Products/Debug-iphonesimulator/Wearwise.app/PlugIns/WearwiseTests.xctest/LocalGarments"
        destination.mkdir(exist_ok=False)
        staged = destination
        for source in files:
            shutil.copyfile(source, staged / source.name)
        (staged / "manifest.json").write_text(json.dumps([path.name for path in files]), encoding="utf-8")
        if looks is not None:
            (staged / "looks.json").write_text(json.dumps(looks), encoding="utf-8")
        result = output / "materials.xcresult"
        tests = ["testLocalImagesNormalizePersistAndReopen", "testLocalImagesExportFlatlayAndRetainDiary"]
        if looks is not None:
            tests.append("testLocalCutoutsCombineWithCharactersAndTransforms")
        selection = [f"-only-testing:WearwiseTests/LocalGarmentMaterialTests/{test}" for test in tests]
        run(common + ["test-without-building"] + selection + [
                      "-parallel-testing-enabled", "NO", "-resultBundlePath", str(result)], log=output / "test.log")
        summary = json.loads(run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result), "--format", "json"]))
        (output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        if summary["passedTests"] != len(tests) or summary["failedTests"] != 0 or summary["skippedTests"] != 0:
            raise RuntimeError(f"Expected {len(tests)} actual passing local-material tests: {summary}")
        run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result), "--output-path", str(output / "attachments")])
        (output / "inputs.json").write_text(json.dumps([
            {"name": path.name, "bytes": path.stat().st_size} for path in files
        ], indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Passed: {len(files)} local images; {len(tests)} native tests. Evidence: {output}", flush=True)
        print("iPhone foreground extraction, cutout colors, system import dialogs, and physical sharing require device acceptance.", flush=True)
    finally:
        if staged is not None and staged.exists():
            shutil.rmtree(staged)
        try:
            if booted:
                run(["xcrun", "simctl", "shutdown", device])
        finally:
            run(["xcrun", "simctl", "delete", device])


if __name__ == "__main__":
    main()
