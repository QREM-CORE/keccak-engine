import sys
import re
import os
import argparse

# ==============================================================================
# Configuration
# ==============================================================================
DEFAULT_LIMIT = 3  # Default number of vectors to extract per file

def get_mode_from_filename(filename):
    """Derives the SystemVerilog Enum mode from the filename."""
    base = os.path.basename(filename).upper()
    if "SHA3-256" in base or "SHA3_256" in base:
        return "SHA3_256", 256
    elif "SHA3-512" in base or "SHA3_512" in base:
        return "SHA3_512", 512
    elif "SHAKE128" in base:
        return "SHAKE128", None
    elif "SHAKE256" in base:
        return "SHAKE256", None
    else:
        return None, None

def parse_rsp_file(filepath, output_file, limit=None):
    filename = os.path.basename(filepath)
    print(f"Processing {filename}...", end=" ")

    mode, default_out_len = get_mode_from_filename(filepath)
    if not mode:
        print(f"\n  [WARN] Could not determine Keccak Mode. Skipping.")
        return

    # Regex patterns
    re_len = re.compile(r"^Len\s*=\s*(\d+)")
    re_msg = re.compile(r"^Msg\s*=\s*([0-9a-fA-F]+)")
    re_md  = re.compile(r"^(MD|Output)\s*=\s*([0-9a-fA-F]+)")
    re_outlen_header = re.compile(r"\[Outputlen\s*=\s*(\d+)\]")
    re_outlen_line = re.compile(r"^Outputlen\s*=\s*(\d+)")

    # State variables
    # Initialize current_len to None so we don't accidentally treat
    # VariableOut files (which lack Len= lines) as length 0.
    current_len = None
    current_msg = ""
    current_out_len = default_out_len

    count_extracted = 0
    count_total = 0

    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # 1. Check for Header Output Length
            m_header = re_outlen_header.search(line)
            if m_header:
                current_out_len = int(m_header.group(1))
                continue

            # 2. Check for Per-Test Output Length (Common in VariableOut)
            m_outlen = re_outlen_line.search(line)
            if m_outlen:
                current_out_len = int(m_outlen.group(1))
                continue

            # 3. Check for Message Length
            m_len = re_len.search(line)
            if m_len:
                current_len = int(m_len.group(1))
                continue

            # 4. Check for Message Data
            m_msg = re_msg.search(line)
            if m_msg:
                current_msg = m_msg.group(1)

                # Only force "EMPTY" if we explicitly saw a Len=0 line.
                # In VariableOut files, current_len remains None, so we keep the hex.
                if current_len is not None and current_len == 0:
                    current_msg = "EMPTY"
                continue

            # 5. Check for Output Hash (Trigger to write)
            m_md = re_md.search(line)
            if m_md:
                digest = m_md.group(2)
                count_total += 1

                # STOP if we hit the limit
                if limit is not None and count_extracted >= limit:
                    continue

                # Fix length if missing (calculate from hex digest)
                if current_out_len is None:
                    current_out_len = len(digest) * 4

                # Write to output
                output_file.write(f"{mode} {current_out_len} {current_msg} {digest}\n")
                count_extracted += 1

                # Reset for next block
                # If this is a VariableOut file, reset length to None so we pick up the next specific length
                if default_out_len is None and "VariableOut" in filepath:
                     current_out_len = None
                elif default_out_len is not None:
                     current_out_len = default_out_len

    # Print summary for this file
    if limit is not None and count_total > limit:
        print(f"-> Extracted {count_extracted} (Skipped {count_total - count_extracted})")
    else:
        print(f"-> Extracted {count_extracted} (All)")

def main():
    parser = argparse.ArgumentParser(description="Parse NIST Keccak .rsp files for SystemVerilog TB.")

    # Allow passing multiple files (e.g. *.rsp)
    parser.add_argument('files', metavar='FILE', type=str, nargs='+',
                        help='The .rsp files to parse')

    parser.add_argument('-o', '--output', type=str, default='vectors.txt',
                        help='Output filename (default: vectors.txt)')

    parser.add_argument('--full', action='store_true',
                        help=f'Parse ALL vectors. If not set, limits to {DEFAULT_LIMIT} per file.')

    args = parser.parse_args()

    # Determine limit
    limit = None if args.full else DEFAULT_LIMIT

    print(f"Writing to {args.output}...")
    if limit:
        print(f"Limiting to {limit} vectors per file (use --full to process all).")

    with open(args.output, 'w') as out_f:
        for f_path in args.files:
            parse_rsp_file(f_path, out_f, limit)

    print("Done.")

if __name__ == "__main__":
    main()
