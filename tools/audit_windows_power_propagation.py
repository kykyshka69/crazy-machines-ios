#!/usr/bin/env python3
"""Read-only instruction verifier for the user's owned CrazyMachines.exe.

No original EXE bytes are bundled in the repository. The verifier accepts
only the precisely studied 2004 PE32 SHA-256 and checks machine instruction
sites + concrete embedded thresholds before printing any claim.
"""
import argparse
import hashlib
import struct
from pathlib import Path

EXPECTED_SHA256 = "51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
INSTRUCTIONS = {
    0x4504C9: bytes.fromhex("c7 40 40 00 00 20 41"),  # battery 10.0f
    0x44BCAC: bytes.fromhex("8b 55 b0 8b 82 e8 00 00 00 50"),  # generator rotor +E8
    0x44BCBE: bytes.fromhex("8b 4d ac d9 59 40"),  # abs(rotor) -> electric +40
    0x44BCC7: bytes.fromhex("d9 42 40 d8 1d 18 3c 4f 00"),  # generator >1
    0x44BCD7: bytes.fromhex("6a 00 6a 00"),  # generator GOAL callback
    0x44BD0E: bytes.fromhex("8b 8d 68 ff ff ff e8 87 0b 00 00"),  # generator propagates

    0x44C8E8: bytes.fromhex("c7 42 40 00 00 00 00"),  # source block = 0
    0x44C8F2: bytes.fromhex("8b 4d 08 8b 51 40 89 50 40"),  # copy src +40 to target +40
    0x450A2D: bytes.fromhex("d9 42 40 d9 e0"),  # motor: load float and reverse sign
    0x450A38: bytes.fromhex("d9 98 e8 00 00 00"),  # store rotor command +E8
    0x450A53: bytes.fromhex("dc 1d a8 fd 4e 00"),  # motor compare qword cutoff
    0x450A60: bytes.fromhex("6a 00 6a 00"),  # channel-0 goal dispatch
    0x44D9C7: bytes.fromhex("d9 42 40 d8 1d 70 73 4e 00"),  # lamp >3
    0x44D9D7: bytes.fromhex("6a 00 6a 00"),  # lamp goal dispatch
    0x450C2D: bytes.fromhex("e8 9e 64 fd ff"),  # bell fabs(source +40)
    0x450C4E: bytes.fromhex("c7 85 34 fc ff ff 00 00 20 41"),  # bell cap 10
    0x450C5E: bytes.fromhex("d8 1d 18 3c 4f 00"),  # bell >1
    0x450C6B: bytes.fromhex("6a 00 6a 00"),  # bell channel-0 GOAL
    0x450E5F: bytes.fromhex("8b 40 40"),  # lightning power signal
    0x450E6E: bytes.fromhex("d8 1d 18 3c 4f 00"),  # lightning >1
    0x450E7F: bytes.fromhex("6a 00 6a 00"),  # lightning goal dispatch
    0x451E21: bytes.fromhex("d9 40 40 d8 35 8c 7a 4e 00"),  # lamp level = power /10
}
SCALARS = {
    0x4E7A8C: 10.0,
    0x4E7370: 3.0,
    0x4F3C18: 1.0,
}
DOUBLES = {0x4EFDA8: 0.5}


def verify(data: bytes) -> dict[str, int]:
    if hashlib.sha256(data).hexdigest() != EXPECTED_SHA256:
        raise ValueError("Expected exact original CrazyMachines.exe hash; refused unknown binary")
    if data[:2] != b"MZ" or len(data) < 0x1000:
        raise ValueError("Not an original Windows executable")
    pe = struct.unpack_from("<I", data, 0x3c)[0]
    if data[pe:pe+4] != b"PE\0\0":
        raise ValueError("Invalid PE32 header")
    number_of_sections = struct.unpack_from("<H", data, pe + 6)[0]
    option_size = struct.unpack_from("<H", data, pe + 20)[0]
    opt = pe + 24
    if struct.unpack_from("<H", data, opt)[0] != 0x10B:
        raise ValueError("Expected 32-bit PE optional header")
    base = struct.unpack_from("<I", data, opt + 28)[0]
    section_offset = opt + option_size
    sections = []
    for i in range(number_of_sections):
        s = section_offset + i * 40
        vsize, va, rawsize, raw = struct.unpack_from("<IIII", data, s+8)
        sections.append((base+va, rawsize, raw))

    def file_offset(virtual_address: int) -> int:
        for va, rawsize, offset in sections:
            if va <= virtual_address < va + rawsize:
                return offset + virtual_address - va
        raise ValueError(f"PE address {virtual_address:x} outside mapped file")

    for va, opcode in INSTRUCTIONS.items():
        offset = file_offset(va)
        if data[offset:offset+len(opcode)] != opcode:
            raise ValueError(f"Power instruction mismatch at Win32 VA 0x{va:X}")
    for va, value in SCALARS.items():
        got = struct.unpack_from("<f", data, file_offset(va))[0]
        if got != value:
            raise ValueError(f"Original threshold mismatch at 0x{va:X}: {got}")
    for va, value in DOUBLES.items():
        got = struct.unpack_from("<d", data, file_offset(va))[0]
        if got != value:
            raise ValueError(f"Original threshold mismatch at 0x{va:X}: {got}")
    return {"instruction_sites": len(INSTRUCTIONS), "scalars": len(SCALARS), "doubles": len(DOUBLES)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("exe", type=Path, help="Private user-owned CrazyMachines.exe")
    args = parser.parse_args()
    result = verify(args.exe.read_bytes())
    print("Authentic Win32 power sites verified:", result)


if __name__ == "__main__":
    main()