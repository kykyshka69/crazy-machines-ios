#!/usr/bin/env python3
"""Original native rocket x86 source SHA gate; no game bytes in GitHub."""
import argparse
import hashlib
import struct
from pathlib import Path
SHA="51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
SITES={
    # Lit native tmo_candle -> original rocket heat region (0x409650)
    0x44E112:"68 a0 c8 4e 00",
    0x44E378:"d9 81 ec 00 00 00",
    0x44E3BD:"e8 8e b2 fb ff",
    0x44E3CC:"d8 1d e8 dd 4e 00",
    0x44E3D7:"75 64",
    0x44E3E6:"e8 45 e9 ff ff",
    # Original 0x44CD30 sets +0xEC =1 and parent ignition clock
    0x44CD79:"c7 81 ec 00 00 00 00 00 80 3f",
    0x44CD91:"dd 99 30 01 00 00",
    # After the parent's first 3-second clock, activate Engine child
    0x44EC51:"d9 81 ec 00 00 00",
    0x44EC72:"dc a1 30 01 00 00",
    0x44EC78:"dc 1d c8 9b 4e 00",
    0x44EC83:"0f 85 aa 03 00 00",
    0x44EE2B:"68 2c ca 4e 00",
    0x44EF5F:"8b 82 24 01 00 00",
    0x44EF6D:"dd 99 30 01 00 00",
    0x44F029:"c7 82 ec 00 00 00 00 00 00 40",
    # Separate flight clock -> physical Engine/Explode -> state 3 + GOAL
    0x44F03B:"d9 05 ac 74 4e 00",
    0x44F041:"d9 80 ec 00 00 00",
    0x44F04B:"f6 c4 44",
    0x44F04E:"0f 8a 58 03 00 00",
    0x44F1A2:"68 98 ca 4e 00",
    0x44F288:"8b 91 24 01 00 00",
    0x44F28E:"dd 02",
    0x44F296:"dc a0 30 01 00 00",
    0x44F29C:"dc 1d c8 9b 4e 00",
    0x44F2A4:"f6 c4 41",
    0x44F2A7:"0f 85 ff 00 00 00",
    0x44F33C:"c7 80 ec 00 00 00 00 00 40 40",
    0x44F354:"e8 07 c1 ff ff",
}
# Additional SHA-checked native region geometry and owner-selector facts:
# 0x409650 deliberately projects both vectors into XY; 0x4204A0
# selects the first (index 0) ORIGINAL region of selector type 3.
# Keep these separate from the 29 historical rocket lifecycle sites.
REGION_SITES={
    0x40966D:"c7 45 f8 00 00 00 00", # source displacement Z = 0
    0x409688:"c7 45 d4 00 00 00 00", # native region axis Z = 0
    0x44E3A4:"6a 00 6a 03",          # region 3, first match
    0x4204FC:"6b c0 54",             # region record stride
    0x420508:"83 7c 02 44 00",      # require linked region pointer
    0x420522:"0f b6 48 10",          # original selector byte
    0x420526:"3b 4d 08",             # match requested selector
    0x44E3B3:"83 c0 24",             # region fields at entry + 0x24
}
# Owner-original Win32 rocket force-at-center path. Keep distinct
# from candle ignition/flight state-machine instruction locations.
FORCE_SITES = {
    0x44F1DD:"68 a8 ca 4e 00",      # original literal Direction
    0x44F1F6:"83 c0 30",            # runtime Direction vector at +0x30
    0x44F219:"8b 91 fc 00 00 00",  # engine child runtime force scalar
    0x44F22D:"e8 2e 52 fb ff",     # native vector times runtime scalar
    0x40446D:"d8 48 08",           # vector component x87 multiply
    0x44F264:"e8 57 6f fd ff",     # body center world-space read
    0x44F27D:"e8 ee 71 fd ff",     # force at center via 0x426470
    0x426502:"e8 f9 fe 05 00",     # 0x426470 calls physics 0x486400
    0x486408:"d8 80 08 01 00 00", # physics force X accumulation
    0x486418:"d8 80 0c 01 00 00", # physics force Y accumulation
    0x486460:"d8 80 18 01 00 00", # physics torque accumulator
    0x486492:"d8 80 20 01 00 00", # last torque component
}
# Original Win32 VELOCITY field is stored into child +0xFC at load time.
VELOCITY_SITES = {
    0x422D35:"68 30 94 4e 00",     # native literal VELOCITY
    0x422D81:"d9 9a fc 00 00 00", # parsed Float32 -> +0xFC
    0x44F219:"8b 91 fc 00 00 00", # rocket Engine reads +0xFC
}
def verify(exe: bytes) -> dict:
    if hashlib.sha256(exe).hexdigest()!=SHA:
        raise ValueError("Original CrazyMachines.exe SHA-256 mismatch")
    if exe[:2]!=b"MZ":raise ValueError("Missing original PE32 header")
    pe=struct.unpack_from("<I",exe,0x3c)[0]
    if exe[pe:pe+4]!=b"PE\0\0":raise ValueError("Invalid PE32 signature")
    count=struct.unpack_from("<H",exe,pe+6)[0]
    optlen=struct.unpack_from("<H",exe,pe+20)[0]
    opt=pe+24
    if struct.unpack_from("<H",exe,opt)[0]!=0x10b:
        raise ValueError("Expected original x86 PE32")
    base=struct.unpack_from("<I",exe,opt+28)[0]
    sections=[]
    for i in range(count):
        row=opt+optlen+40*i
        _,vs,rva,rs,raw=struct.unpack_from("<8sIIII",exe,row)
        sections.append((base+rva,max(vs,rs),raw))
    def read(va,n):
        for start,sz,raw in sections:
            if start<=va and va+n<=start+sz:
                pos=raw+va-start
                if pos+n<=len(exe):return exe[pos:pos+n]
        raise ValueError("Native original rocket address not mapped")
    for address,code in {**SITES,**REGION_SITES,**FORCE_SITES,**VELOCITY_SITES}.items():
        expected=bytes.fromhex(code)
        if read(address,len(expected))!=expected:
            raise ValueError("Native original rocket x86 mismatch at "+hex(address))
    if read(0x4E9430,9)!=b"VELOCITY\0":
        raise ValueError("Original native VELOCITY script keyword mismatch")
    if read(0x4EC8A0,11)!=b"tmo_candle\0":
        raise ValueError("Original candle heat source selector mismatch")
    if read(0x4ECA2C,16)!=b"tmo_heat_rocket\0":
        raise ValueError("Original pre-launch rocket type selector mismatch")
    if read(0x4EDDE8,4)!=bytes.fromhex("3d0a573f"):
        raise ValueError("Original physical candle ignition threshold mismatch")
    if struct.unpack("<f",read(0x4F3B9C,4))[0]!=0:
        raise ValueError("Original idle heat target state mismatch")
    if read(0x4ECA98,16)!=b"tmo_heat_rocket\0":
        raise ValueError("Original rocket type selector mismatch")
    if struct.unpack("<f",read(0x4E74AC,4))[0]!=2.0:
        raise ValueError("Native rocket flying state mismatch")
    if struct.unpack("<d",read(0x4E9BC8,8))[0]!=3.0:
        raise ValueError("Native original rocket fuse mismatch")
    return {"x86_sites":len(SITES),
            "native_region_geometry_sites":len(REGION_SITES),
            "native_force_sites":len(FORCE_SITES),
            "native_velocity_sites":len(VELOCITY_SITES),
            "native_region_plane":"XY", "ignited_state":1,
            "native_candle_ignition_cutoff":
                struct.unpack("<f",read(0x4EDDE8,4))[0],
            "prelaunch_strict_seconds":3, "flying_state":2,
            "flight_strict_seconds":3, "exploded_state":3,
            "separate_rocket_and_engine_clocks":True}
if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_exe",type=Path)
    print(verify(parser.parse_args().original_exe.read_bytes()))
