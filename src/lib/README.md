# TAR Library for MoonBit

A simplified TAR archive library implementation in MoonBit, focusing on core functionality and ease of use.

## Features

- ✅ Create and manage TAR archives
- ✅ Add files and directories to archives
- ✅ Extract files from archives
- ✅ List archive contents
- ✅ Archive statistics
- ✅ Round-trip create/extract operations
- ✅ Comprehensive test suite (11 tests passing)

## API Reference

### Core Types

```moonbit
/// File type indicators
pub enum FileType {
  Normal      // Regular file
  Directory   // Directory
  Symlink     // Symbolic link (placeholder)
}

/// Simple TAR header
pub struct SimpleHeader {
  name : String
  size : Int
  file_type : FileType
}

/// TAR entry
pub struct TarEntry {
  header : SimpleHeader
  data : String
}

/// TAR archive
pub struct TarArchive {
  entries : Array[TarEntry]
}

/// Archive statistics
pub struct ArchiveStats {
  total_entries : Int
  file_count : Int
  directory_count : Int
  total_size : Int
}
```

### Main Functions

#### Creating Archives

```moonbit
// Create a new empty archive
let archive = TarArchive::new()

// Add a file
archive.add_file("example.txt", "Hello, world!")

// Add a directory
archive.add_directory("docs")

// Create archive from file list
let files = [("file1.txt", "Content 1"), ("file2.txt", "Content 2")]
let archive = create_simple_archive(files)
```

#### Reading Archives

```moonbit
// Get all entries
let entries = archive.get_entries()

// List file names
let names = archive.list_names()

// Find specific entry
match archive.find_entry("example.txt") {
  Some(entry) => println("Found: " + entry.data)
  None => println("Not found")
}

// Get archive statistics
let stats = archive.get_stats()
println("Files: " + stats.file_count.to_string())
```

#### Extracting Files

```moonbit
// Extract all files (directories are skipped)
let files = extract_simple_archive(archive)

// Process extracted files
let mut i = 0
while i < files.length() {
  let (name, content) = files[i]
  println(name + ": " + content)
  i = i + 1
}
```

## Example Usage

```moonbit
// Create a new archive
let archive = TarArchive::new()

// Add some content
archive.add_file("README.md", "# My Project\n\nThis is a test project.")
archive.add_directory("src")
archive.add_file("src/main.mbt", "fn main() { println(\"Hello!\") }")

// Check archive info
println("Archive has " + archive.count().to_string() + " entries")

let stats = archive.get_stats()
println("Files: " + stats.file_count.to_string() + 
        ", Directories: " + stats.directory_count.to_string() +
        ", Total size: " + stats.total_size.to_string() + " bytes")

// Round-trip test
let files = [("test1.txt", "Content 1"), ("test2.txt", "Content 2")]
let test_archive = create_simple_archive(files)
let extracted = extract_simple_archive(test_archive)

println("Original: " + files.length().to_string() + " files")
println("Extracted: " + extracted.length().to_string() + " files")
```

## Testing

The library includes a comprehensive test suite with 11 tests covering:

- Archive creation and management
- File and directory operations
- Entry lookup and statistics
- Round-trip create/extract operations
- Edge cases and error conditions

Run tests with:
```bash
moon test
```

## Implementation Notes

This is a simplified implementation focused on:

1. **Ease of use**: Simple API for common operations
2. **MoonBit compatibility**: Uses MoonBit-native types and patterns
3. **Memory efficiency**: In-memory operations without complex streaming
4. **Test coverage**: Comprehensive test suite ensures correctness

### Limitations

- No actual TAR format serialization (simplified in-memory representation)
- No compression support
- No advanced TAR features (permissions, timestamps, etc.)
- Symlink support is placeholder only

This implementation serves as a foundation that could be extended to support full TAR format compliance and additional features as needed.

## License

ISC License - See LICENSE file for details.
