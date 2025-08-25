// Example usage of the TAR library

pub fn demo_tar_library() -> Unit {
  println("=== TAR Library Example ===")
  
  // Create a new archive
  let archive = TarArchive::new()
  
  // Add some files
  archive.add_file("README.md", "# My Project\n\nThis is a test project.")
  archive.add_file("main.mbt", "fn main() {\n  println(\"Hello, world!\")\n}")
  archive.add_directory("docs")
  archive.add_file("docs/guide.md", "## User Guide\n\nHow to use this project...")
  
  println("Created archive with " + archive.count().to_string() + " entries")
  
  // Show archive contents
  println("\nArchive contents:")
  let names = archive.list_names()
  let mut i = 0
  while i < names.length() {
    println("  - " + names[i])
    i = i + 1
  }
  
  // Show statistics
  let stats = archive.get_stats()
  println("\nArchive statistics:")
  println("  Total entries: " + stats.total_entries.to_string())
  println("  Files: " + stats.file_count.to_string())
  println("  Directories: " + stats.directory_count.to_string())
  println("  Total size: " + stats.total_size.to_string() + " bytes")
  
  // Demonstrate round-trip
  println("\n=== Round-trip Test ===")
  let test_files = [("file1.txt", "Content 1"), ("file2.txt", "Content 2")]
  let test_archive = create_simple_archive(test_files)
  let extracted = extract_simple_archive(test_archive)
  
  println("Original files: " + test_files.length().to_string())
  println("Extracted files: " + extracted.length().to_string())
  
  println("\nExtracted content:")
  let mut j = 0
  while j < extracted.length() {
    let (name, content) = extracted[j]
    println("  " + name + ": " + content)
    j = j + 1
  }
  
  // Find specific entry
  println("\n=== Entry Lookup ===")
  match archive.find_entry("main.mbt") {
    Some(entry) => {
      println("Found main.mbt:")
      println("  Size: " + entry.header.size.to_string() + " bytes")
      let preview = if entry.data.length() > 20 { 
        entry.data.substring(end=20) + "..." 
      } else { 
        entry.data 
      }
      println("  Content preview: " + preview)
    }
    None => println("main.mbt not found")
  }
  
  println("\n=== Example Complete ===")
}
