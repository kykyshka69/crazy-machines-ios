"""Recovered byte transforms from original CrazyMachines.exe x86 code.

These primitives are grounded in disassembly. The full CML decoding
sequence and its invocation parameters are not yet validated.
"""


def reverse_bytes(data: bytes) -> bytes:
    """0x47E480: reverse a buffer."""
    return data[::-1]


def offset_arithmetic(data: bytes, initial: int, add: bool) -> bytes:
    """0x47E4D0: position-dependent byte add/subtract (mod 256).

    The signed initial byte is sign-extended by the x86 instruction.
    Its low 8 bits are sufficient for modular arithmetic.
    """
    length = len(data)
    return bytes(
        (byte + (initial + length + index) if add
         else byte - (initial + length + index)) & 0xFF
        for index, byte in enumerate(data)
    )


def adjacent_delta(data: bytes, forward: bool) -> bytes:
    """0x47E570: cumulative sum or first difference (modulo 256).

    Rechecked against x86 0x47E5B0-0x47E5CA: the forward path reads
    the *already updated* previous destination byte; the reverse path
    subtracts the *original* previous byte held in a temporary copy.
    """
    if not data:
        return b""
    result = bytearray(data)
    if forward:
        for index in range(1, len(data)):
            result[index] = (data[index] + result[index - 1]) & 0xFF
    else:
        for index in range(1, len(data)):
            result[index] = (data[index] - data[index - 1]) & 0xFF
    return bytes(result)


def apply_control_pairs(data: bytes, control: bytes, *, encode: bool) -> bytes:
    """Dispatch original 0x47E610 operations by signed byte remainder mod 3.

    The encoder reads each (parameter, selector) pair. The decoder reads
    (selector, parameter) pairs, as shown at 0x47E790 and 0x47E691.
    This is the primitive dispatch only; file framing is handled separately.
    """
    if len(control) % 2:
        raise ValueError("control length must be even")
    result = data
    for index in range(0, len(control), 2):
        first, second = control[index:index + 2]
        parameter, selector = (first, second) if encode else (second, first)
        signed_selector = selector if selector < 128 else selector - 256
        quotient = abs(signed_selector) // 3
        remainder = signed_selector - (-quotient if signed_selector < 0 else quotient) * 3
        if remainder == 0:
            result = reverse_bytes(result)
        elif remainder == 1:
            result = offset_arithmetic(result, parameter, add=encode)
        elif remainder == 2:
            result = adjacent_delta(result, forward=encode)
        # Negative signed remainders -1 and -2 are intentionally no-ops:
        # the original x86 switch handles only 0, 1, 2.
    return result
