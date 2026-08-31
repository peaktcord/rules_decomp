"""Verify named private files against a checked-in SHA-256/size manifest."""

import argparse
import hashlib
from pathlib import Path


def parse_manifest(path):
    expected = {}
    for number, raw in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) not in (2, 3):
            raise ValueError(f"{path}:{number}: expected SHA256 [SIZE] NAME")
        digest = fields[0].lower()
        if len(fields) == 2:
            size = None
            name = fields[1].lstrip("*")
        else:
            size = int(fields[1])
            name = fields[2].lstrip("*")
        if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise ValueError(f"{path}:{number}: invalid SHA-256")
        if name in expected:
            raise ValueError(f"{path}:{number}: duplicate name {name}")
        expected[name] = (digest, size)
    return expected


def digest(path):
    value = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--file", action="append", default=[])
    args = parser.parse_args()

    actual = {}
    for specification in args.file:
        name, separator, path = specification.partition("=")
        if not separator or not name or not path:
            parser.error(f"invalid --file value: {specification}")
        if name in actual:
            parser.error(f"duplicate input basename: {name}")
        actual[name] = path

    expected = parse_manifest(args.manifest)
    if set(actual) != set(expected):
        missing = sorted(set(expected) - set(actual))
        unknown = sorted(set(actual) - set(expected))
        raise SystemExit(f"private input set mismatch; missing={missing}, unknown={unknown}")

    lines = []
    for name in sorted(expected):
        expected_digest, expected_size = expected[name]
        path = actual[name]
        size = Path(path).stat().st_size
        if expected_size is not None and size != expected_size:
            raise SystemExit(f"{name}: size {size}, expected {expected_size}")
        actual_digest = digest(path)
        if actual_digest != expected_digest:
            raise SystemExit(f"{name}: SHA-256 {actual_digest}, expected {expected_digest}")
        lines.append(f"{actual_digest} {size} {name}")

    Path(args.output).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
