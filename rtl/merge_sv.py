import os
import glob

def concatenate_sv_files(input_directory, output_filename):
    """
    Concatenates all .sv files in the given directory into a single file.
    """
    # Create the full path for the search pattern
    search_pattern = os.path.join(input_directory, "*.sv")
    
    # Get a list of all matching files
    files = glob.glob(search_pattern)
    
    # Sort files to ensure deterministic order (optional, but recommended)
    files.sort()

    if not files:
        print(f"No .sv files found in {input_directory}")
        return

    print(f"Found {len(files)} files. Merging...")

    with open(output_filename, 'w') as outfile:
        for file_path in files:
            file_name = os.path.basename(file_path)
            
            # Create a separator to make the merged file readable
            header = f"\n// {'='*60}\n// SOURCE FILE: {file_name}\n// {'='*60}\n"
            
            try:
                with open(file_path, 'r') as infile:
                    # Write the header
                    outfile.write(header)
                    # Write the file content
                    outfile.write(infile.read())
                    # Ensure there is a newline at the end of each file block
                    outfile.write("\n")
                    
                print(f"Added: {file_name}")
            except IOError as e:
                print(f"Error reading {file_name}: {e}")

    print(f"\nSuccess! All files merged into: {output_filename}")

if __name__ == "__main__":
    # --- CONFIGURATION ---
    # Change '.' to the path of your folder if it's not the current one
    TARGET_DIRECTORY = '.' 
    
    # The name of the final combined file
    OUTPUT_FILE = 'combined_design.sv' 
    # ---------------------

    concatenate_sv_files(TARGET_DIRECTORY, OUTPUT_FILE)
