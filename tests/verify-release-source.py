"""Verify full-kit ZIP payloads byte-for-byte against an exact Git commit."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import subprocess
import zipfile


def verify(archive, commit):
    tracked = subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', commit], text=True
    ).splitlines()
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        assert bundle.testzip() is None, 'ZIP corruption'
        assert len(names) == len(set(names)), 'duplicate ZIP members'
        for name in names:
            path = PurePosixPath(name)
            assert not path.is_absolute() and '..' not in path.parts and '\\' not in name, name
            folder, rel = name.split('/', 1)
            assert folder in ('1', '2'), name
            if rel == 'START-HERE.bat':
                source = 'kits/' + folder + '/START-HERE.bat'
            elif rel.startswith('policy/'):
                source = rel
            elif rel.startswith('revert-docs/'):
                source = 'revert/docs/' + rel.split('/', 1)[1]
            else:
                candidates = [p for p in tracked if PurePosixPath(p).name == PurePosixPath(rel).name]
                assert len(candidates) == 1, (name, candidates)
                source = candidates[0]
            expected = subprocess.check_output(['git', 'show', commit + ':' + source])
            assert bundle.read(name) == expected, ('source mismatch', name, source)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    assert archive.with_suffix('.zip.sha256').read_text().split()[0] == digest, 'checksum mismatch'
    print(f'PASS: {len(names)} members exactly match {commit}; SHA256 {digest}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--commit', default='HEAD')
    args = parser.parse_args()
    verify(args.archive, args.commit)
