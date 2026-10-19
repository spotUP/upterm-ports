"""ipk.py: tiny .ipk and Packages.gz builder shared by the opkg check scripts (not a check itself:
the recipe runs only check/*.sh). A script imports it with sys.path.insert(0, <check dir>)."""
import gzip, hashlib, io, tarfile


def targz(files):
    """files: (name, data) or (name, data, mode) tuples, as a gzipped GNU tar"""
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode='w', format=tarfile.GNU_FORMAT) as tf:
        for f in files:
            name, data, mode = f if len(f) == 3 else (f[0], f[1], 0o644)
            ti = tarfile.TarInfo(name); ti.size = len(data); ti.mode = mode
            tf.addfile(ti, io.BytesIO(data))
    out = io.BytesIO()
    with gzip.GzipFile(filename='', mode='wb', fileobj=out, mtime=0) as gz:
        gz.write(raw.getvalue())
    return out.getvalue()


def ar(members):
    out = b'!<arch>\n'
    for name, data in members:
        out += b'%-16s%-12d%-6d%-6d%-8s%-10d`\n' % ((name + '/').encode(), 0, 0, 0, b'100644', len(data))
        out += data + (b'\n' if len(data) % 2 else b'')
    return out


def ipk(control_files, data_files):
    return ar([('debian-binary', b'2.0\n'), ('control.tar.gz', targz(control_files)),
               ('data.tar.gz', targz(data_files))])


def stanza(ctl, filename, ipk_bytes, sha=None):
    """ctl plus the Filename/Size/SHA256sum lines of a Packages entry"""
    sha = sha or hashlib.sha256(ipk_bytes).hexdigest()
    return ctl + b'Filename: %s\nSize: %d\nSHA256sum: %s\n' % (filename.encode(), len(ipk_bytes), sha.encode())


def write_index(path, text):
    with gzip.GzipFile(path, 'wb', mtime=0) as gz:
        gz.write(text)
