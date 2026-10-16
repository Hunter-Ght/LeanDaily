import struct
import unittest

from check_apk import check_elf


def library():
    # Small ELF64 fixture with a string table, SHT_DYNAMIC and SHT_DYNSYM.
    data = bytearray(64 + 4 * 64)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 40, 64)
    struct.pack_into('<HHH', data, 58, 64, 4, 1)
    for i, kind in enumerate((0, 3, 6, 11)):
        struct.pack_into('<IIQQQQIIQQ', data, 64 + i * 64,
                         0, kind, 0, 0, 320, 0, 0, 0, 0, 0)
    return data


class ElfCheckTest(unittest.TestCase):
    def test_kept_section_headers(self):
        check_elf(library())

    def test_previous_sstrip_regression(self):
        data = library()
        struct.pack_into('<Q', data, 40, 0)
        struct.pack_into('<HHH', data, 58, 0, 0, 0)
        with self.assertRaisesRegex(ValueError, 'has no section headers'):
            check_elf(data)

    def test_truncated_section_table(self):
        with self.assertRaisesRegex(ValueError, '越界'):
            check_elf(library()[:-1])

    def test_missing_dynamic_section(self):
        data = library()
        struct.pack_into('<I', data, 64 + 2 * 64 + 4, 1)
        with self.assertRaisesRegex(ValueError, '动态链接'):
            check_elf(data)

    def test_unstripped_engine(self):
        data = library()
        names = b'\0.debug_info\0'
        data.extend(names)
        struct.pack_into('<Q', data, 64 + 64 + 32, len(names))
        struct.pack_into('<I', data, 64 + 2 * 64, 1)
        with self.assertRaisesRegex(ValueError, '调试信息'):
            check_elf(data, require_stripped=True)


if __name__ == '__main__':
    unittest.main()
