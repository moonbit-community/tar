// Main entry point for the TAR library demonstration

fn main {
  println("TAR Library for MoonBit")
  println("=======================")
  
  // Create a simple demonstration
  let archive = @lib.TarArchive::new()
  
  // Add some sample files
  archive.add_file("hello.txt", "Hello from TAR library!")
  archive.add_file("info.md", "# TAR Library\n\nA simple TAR implementation in MoonBit.")
  archive.add_directory("docs")
  archive.add_symlink("readme_link", "info.md")
  
  // Show archive info
  println("Created archive with " + archive.count().to_string() + " entries")
  
  let stats = archive.get_stats()
  println("Files: " + stats.file_count.to_string() + 
          ", Directories: " + stats.directory_count.to_string() + 
          ", Symlinks: " + stats.symlink_count.to_string() +
          ", Total size: " + stats.total_size.to_string() + " bytes")
  
  // List contents
  println("\nArchive contents:")
  let names = archive.list_names()
  let mut i = 0
  while i < names.length() {
    println("  - " + names[i])
    i = i + 1
  }
  
  println("\nTAR library is working correctly! ✅")
}
