#!/usr/bin/env python3

"""
Implements the ι (iota) step of the Keccak-f[1600] permutation.

This script dynamically calculates the round constant (RC) for each round
by implementing Algorithm 5 (rc(t)) and Algorithm 6 from the
Keccak specification (as seen in FIPS 202).
"""

# 64-bit mask for all bitwise operations
MASK_64 = 0xFFFFFFFFFFFFFFFF

def _calculate_rc(t):
    """
    Calculates the single-bit output of the rc(t) function (Algorithm 5).

    This is a Linear Feedback Shift Register (LFSR).

    t: integer input
    Returns: a single bit (1 or 0)
    """
    # Step 1: If t mod 255 == 0, return 1.
    if t % 255 == 0:
        return 1

    # Step 2: Let R = 10000000 (binary)
    R = 0x80  # 8-bit integer

    # Step 3: For i from 1 to t mod 255
    t_mod_255 = t % 255
    for _ in range(t_mod_255):
        # R is an 8-bit register [r0, r1, r2, r3, r4, r5, r6, r7]
        # We need to implement the 9-bit intermediate state

        # Get the 8 bits of R
        R_list = [(R >> (7-i)) & 1 for i in range(8)]

        # a. R = 0 || R (R is now 9 bits)
        # R9 = [0, r0, r1, r2, r3, r4, r5, r6, r7]
        R9 = [0] + R_list

        # The feedback bit is R[8] (which is the old r7)
        feedback_bit = R9[8]

        # b. R[0] = R[0] XOR R[8]
        R9[0] ^= feedback_bit
        # c. R[4] = R[4] XOR R[8]
        R9[4] ^= feedback_bit
        # d. R[5] = R[5] XOR R[8]
        R9[5] ^= feedback_bit
        # e. R[6] = R[6] XOR R[8]
        R9[6] ^= feedback_bit

        # f. R = Trunc8(R) (take the first 8 bits, R[0]...R[7])
        R_trunc = R9[0:8]

        # Convert R_trunc back to an 8-bit integer for the next loop
        R = 0
        for bit in R_trunc:
            R = (R << 1) | bit

    # Step 4: Return R[0] (the MSB of the final 8-bit R)
    return (R >> 7) & 1

def _get_round_constant(i_r):
    """
    Calculates the 64-bit round constant (RC) for round i_r.
    Implements Steps 2 and 3 from Algorithm 6.

    i_r: The round index (0-23)
    Returns: A 64-bit integer round constant
    """
    # For Keccak-f[1600], w = 64, so l = log2(w) = 6
    l = 6

    # Step 2: Let RC = 0
    RC = 0

    # Step 3: For j from 0 to l
    for j in range(l + 1):  # j goes from 0 to 6
        # Calculate t = j + 7*i_r
        t = j + (7 * i_r)

        # Get the bit from Algorithm 5
        bit = _calculate_rc(t)

        # If the bit is 1, set the corresponding bit in RC
        if bit == 1:
            # The position is (2^j - 1)
            # j=0 -> pos = 0
            # j=1 -> pos = 1
            # j=2 -> pos = 3
            # j=3 -> pos = 7
            # j=4 -> pos = 15
            # j=5 -> pos = 31
            # j=6 -> pos = 63
            pos = (1 << j) - 1

            # Set the bit at `pos` in the RC integer
            RC |= (1 << pos)

    return RC & MASK_64


def keccak_iota(state, round_index):
    """
    Perform the ι (iota) step mapping (Algorithm 6) on a 5x5 Keccak state.
    This XORs a dynamically calculated round constant (RC) into lane (0,0).

    state: list of 5 lists, each with 5 64-bit integers.
    round_index: The round number (i_r), from 0 to 23.
    Returns a new 5x5 list after ι step.
    """
    # Step 1: Copy state A to A' (A'[x,y,z] = A[x,y,z])
    # We only modify (0,0), so a shallow copy of rows is sufficient.
    A_prime = [row[:] for row in state]

    # Step 2-3: Calculate the 64-bit Round Constant (RC)
    if not (0 <= round_index < 24):
        raise ValueError("Round index must be between 0 and 23 for Keccak-f[1600].")

    RC = _get_round_constant(round_index)

    # Step 4: A'[0, 0, z] = A'[0, 0, z] ⊕ RC[z]
    # This is a lane-wise XOR on lane (0,0).
    A_prime[0][0] = (A_prime[0][0] ^ RC) & MASK_64

    # Step 5: Return A'
    return A_prime


def print_state_fips(state):
    """
    Prints the 5x5 Keccak state with (0,0) at the center (bottom middle),
    as specified by FIPS 202, using 16 hex digits per lane.
    """
    print("Keccak state (FIPS 202 coordinates):\n")
    for y in range(4, -1, -1):
        row = []
        for x in range(5):
            row.append(f"0x{state[x][y]:016x}")
        print(f"y={y}: " + "  ".join(row))
    print("      x=0                x=1                x=2                x=3                x=4\n")


# === Example Test for IOTA (ι) ===

print("="*30)
print("Testing IOTA (ι) Step")
print("="*30)

# Test 1: Round 0
state_zero = [[0]*5 for _ in range(5)]
round_idx = 0
rc_val_0 = _get_round_constant(round_idx)
print(f"==== Initial State (All Zeros) | Round: {round_idx} ====")
print(f"Calculated RC[{round_idx}] = 0x{rc_val_0:016x}")
print_state_fips(state_zero)

after_iota = keccak_iota(state_zero, round_idx)
print(f"==== After ι Step (Round {round_idx}) ====")
print_state_fips(after_iota)
print(f"Note: Lane (0,0) is now 0x0 ^ RC[0] = 0x{rc_val_0:016x}\n")

# Test 2: Round 1
round_idx = 1
rc_val_1 = _get_round_constant(round_idx)
print(f"==== Initial State (All Zeros) | Round: {round_idx} ====")
print(f"Calculated RC[{round_idx}] = 0x{rc_val_1:016x}")
print_state_fips(state_zero)

after_iota = keccak_iota(state_zero, round_idx)
print(f"==== After ι Step (Round {round_idx}) ====")
print_state_fips(after_iota)
print(f"Note: Lane (0,0) is now 0x0 ^ RC[1] = 0x{rc_val_1:016x}\n")

# Test 3: Round 23 (last round)
round_idx = 23
rc_val_23 = _get_round_constant(round_idx)
print(f"==== Initial State (All Zeros) | Round: {round_idx} ====")
print(f"Calculated RC[{round_idx}] = 0x{rc_val_23:016x}")
print_state_fips(state_zero)

after_iota = keccak_iota(state_zero, round_idx)
print(f"==== After ι Step (Round {round_idx}) ====")
print_state_fips(after_iota)
print(f"Note: Lane (0,0) is now 0x0 ^ RC[23] = 0x{rc_val_23:016x}\n")

# Test 4: XORing a non-zero lane
state_non_zero = [[0]*5 for _ in range(5)]
state_non_zero[0][0] = 0xAAAAAAAAAAAAAAAA
round_idx = 1
print(f"==== Initial State (A's at (0,0)) | Round: {round_idx} ====")
print(f"Calculated RC[{round_idx}] = 0x{rc_val_1:016x}")
print_state_fips(state_non_zero)

after_iota = keccak_iota(state_non_zero, round_idx)
print(f"==== After ι Step (Round {round_idx}) ====")
print_state_fips(after_iota)
expected_val = (0xAAAAAAAAAAAAAAAA ^ rc_val_1) & MASK_64
print(f"Note: Lane (0,0) is now 0xAAAAAAAAAAAAAAAA ^ 0x{rc_val_1:016x} = 0x{expected_val:016x}\n")
