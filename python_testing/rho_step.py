def keccak_rho(state):
    """
    Perform the ρ step mapping on a 5x5 array of 64-bit integers.
    Each lane is rotated left by a position-dependent offset.
    state: list of 5 lists, each with 5 64-bit integers.
    Returns a new 5x5 list after ρ step.
    """

    # Rotation offsets (Y×X grid — matches Verilog layout)
    OFFSETS = [
        [  0, 36,  3, 41, 18 ],
        [  1, 44, 10, 45,  2 ],
        [ 62,  6, 43, 15, 61 ],
        [ 28, 55, 25, 21, 56 ],
        [ 27, 20, 39,  8, 14 ]
    ]

    def rotl64(value, shift):
        """Rotate left in 64-bit space."""
        shift %= 64
        if shift == 0:
            return value & 0xFFFFFFFFFFFFFFFF
        return ((value << shift) & 0xFFFFFFFFFFFFFFFF) | (value >> (64 - shift))

    result = [[0]*5 for _ in range(5)]
    for x in range(5):
        for y in range(5):
            result[x][y] = rotl64(state[x][y], OFFSETS[x][y])

    return result


def print_state_fips(state):
    """
    Prints the 5x5 Keccak state with (0,0) at the center (bottom middle),
    as specified by FIPS 202, using 16 hex digits per lane.
    """
    print("Keccak state (FIPS 202 coordinates):\n")
    for y in range(4, -1, -1):  # print y = 4 down to 0 (top to bottom)
        row = []
        for x in range(5):
            row.append(f"0x{state[x][y]:016x}")
        print(f"y={y}: " + "  ".join(row))
    print("     x=0                 x=1                 x=2                 x=3                 x=4\n")



# Example test: single-bit input state
state = [[0]*5 for _ in range(5)]
state[1][0] = 0x1  # single bit set in lane (0,0)

print("Starting State: One bit set at (1,0):")
print_state_fips(state)
after_rho = keccak_rho(state)
print("After rho step: One bit set at (1,0):")
print_state_fips(after_rho)

print("Starting State: All lanes set to 0x1")
# Set each lane to value 1
state = [[1 for _ in range(5)] for _ in range(5)]
print_state_fips(state)
print("After rho step: All lanes set to 0x1:")
after_rho = keccak_rho(state)
print_state_fips(after_rho)
