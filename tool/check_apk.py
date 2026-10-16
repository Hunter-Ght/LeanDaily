#!/usr/bin/env python3
"""发布前检查 APK：拒绝缺失 ELF 区段表的原生库和夹带调试信息的包。"""
import argparse
import struct
import zipfile


def check_elf(data: bytes, require_stripped: bool = False) -> None:
    if len(data) < 64 or data[:4] != b'\x7fELF' or data[5] != 1:
        raise ValueError('不是有效的小端 ELF')
    if data[4] == 2:
        shoff = struct.unpack_from('<Q', data, 40)[0]
        entsize, count, strings = struct.unpack_from('<HHH', data, 58)
        fmt, expected = '<IIQQQQIIQQ', 64
    elif data[4] == 1:
        shoff = struct.unpack_from('<I', data, 32)[0]
        entsize, count, strings = struct.unpack_from('<HHH', data, 46)
        fmt, expected = '<IIIIIIIIII', 40
    else:
        raise ValueError('未知 ELF 位数')
    if not shoff or not count:
        raise ValueError('缺失 ELF 区段表，Android API 24+ 会拒绝加载 (has no section headers)')
    if entsize != expected or shoff + count * entsize > len(data) or strings >= count:
        raise ValueError('ELF 区段表越界或格式错误')
    sections = [struct.unpack_from(fmt, data, shoff + i * entsize) for i in range(count)]
    names_section = sections[strings]
    names = data[names_section[4]:names_section[4] + names_section[5]]
    types = set()
    for section in sections:
        name_offset, kind, _, _, offset, size, *_ = section
        types.add(kind)
        if kind != 8 and offset + size > len(data):  # SHT_NOBITS 不占文件空间
            raise ValueError('ELF 区段数据越界')
        name = names[name_offset:].split(b'\0', 1)[0]
        if require_stripped and name.startswith((b'.debug_', b'.zdebug_')):
            raise ValueError('仍含调试信息，请安装完整 NDK 并让 AGP 使用 llvm-strip')
    if not {6, 11}.issubset(types):  # SHT_DYNAMIC, SHT_DYNSYM
        raise ValueError('缺失动态链接区段')


def check_apk(path: str, max_mib: float = 40) -> None:
    with zipfile.ZipFile(path) as apk:
        libs = [n for n in apk.namelist() if n.startswith('lib/') and n.endswith('.so')]
        if not libs or not any(n.endswith('/libflutter.so') for n in libs):
            raise ValueError('APK 未包含 Flutter 引擎')
        for name in libs:
            try:
                check_elf(apk.read(name), require_stripped=name.endswith('/libflutter.so'))
            except ValueError as error:
                raise ValueError(f'{name}: {error}') from error
        size = apk.fp.seek(0, 2) / 1048576
        if size > max_mib:
            raise ValueError(f'APK {size:.1f} MiB 超过 {max_mib:.1f} MiB 限制')
        print(f'APK 检查通过：{len(libs)} 个 ELF 库，{size:.1f} MiB')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk')
    parser.add_argument('--max-mib', type=float, default=40)
    args = parser.parse_args()
    try:
        check_apk(args.apk, args.max_mib)
    except (ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, f'APK 检查失败：{error}\n')
