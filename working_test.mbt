// Working tests for the simplified TAR library

test "Create empty archive" {
  let archive = @tar.TarArchive::new()
  if !archive.is_empty() {
    fail("New archive should be empty")
  }
  if archive.count() != 0 {
    fail("New archive should have 0 entries")
  }
}

test "Add files to archive" {
  let archive = @tar.TarArchive::new()
  
  archive.add_file("test.txt", "Hello, world!")
  archive.add_file("another.txt", "Another file")
  
  if archive.count() != 2 {
    fail("Archive should have 2 entries")
  }
  
  let names = archive.list_names()
  if names.length() != 2 {
    fail("Should have 2 file names")
  }
  if names[0] != "test.txt" {
    fail("First file should be test.txt")
  }
  if names[1] != "another.txt" {
    fail("Second file should be another.txt")
  }
}

test "Add directories to archive" {
  let archive = @tar.TarArchive::new()
  
  archive.add_directory("dir1")
  archive.add_directory("dir2/")  // Already has trailing slash
  
  if archive.count() != 2 {
    fail("Archive should have 2 entries")
  }
  
  let entries = archive.get_entries()
  
  // Check that both entries are directories using match
  match entries[0].header.file_type {
    Directory => ()  // Expected
    _ => fail("First entry should be a directory")
  }
  
  match entries[1].header.file_type {
    Directory => ()  // Expected
    _ => fail("Second entry should be a directory")
  }
  
  // Both should end with '/'
  let name0 = entries[0].header.name
  let name1 = entries[1].header.name
  if name0.length() == 0 || name0[name0.length() - 1] != '/' {
    fail("Directory name should end with /")
  }
  if name1.length() == 0 || name1[name1.length() - 1] != '/' {
    fail("Directory name should end with /")
  }
}

test "Find entries by name" {
  let archive = @tar.TarArchive::new()
  
  archive.add_file("findme.txt", "Found!")
  archive.add_file("other.txt", "Other content")
  
  match archive.find_entry("findme.txt") {
    Some(entry) => {
      if entry.data != "Found!" {
        fail("Found entry should have correct content")
      }
    }
    None => fail("Should find the entry")
  }
  
  match archive.find_entry("nonexistent.txt") {
    Some(_) => fail("Should not find non-existent entry")
    None => ()  // Expected
  }
}

test "Archive statistics" {
  let archive = @tar.TarArchive::new()
  
  archive.add_file("file1.txt", "Hello")      // 5 bytes
  archive.add_file("file2.txt", "World!")     // 6 bytes
  archive.add_directory("testdir")
  
  let stats = archive.get_stats()
  
  if stats.total_entries != 3 {
    fail("Should have 3 total entries")
  }
  if stats.file_count != 2 {
    fail("Should have 2 files")
  }
  if stats.directory_count != 1 {
    fail("Should have 1 directory")
  }
  if stats.symlink_count != 0 {
    fail("Should have 0 symlinks")
  }
  if stats.total_size != 11 {
    fail("Total size should be 11 bytes")
  }
}

test "Create archive from files array" {
  let files = [("a.txt", "A"), ("b.txt", "B"), ("c.txt", "C")]
  let archive = @tar.create_simple_archive(files)
  
  if archive.count() != 3 {
    fail("Archive should have 3 entries")
  }
  
  let names = archive.list_names()
  if names[0] != "a.txt" || names[1] != "b.txt" || names[2] != "c.txt" {
    fail("Files should be in correct order")
  }
}

test "Extract files from archive" {
  let archive = @tar.TarArchive::new()
  
  archive.add_file("extract1.txt", "Content 1")
  archive.add_file("extract2.txt", "Content 2")
  archive.add_directory("skip_this_dir")  // Should be skipped in extraction
  
  let extracted = @tar.extract_simple_archive(archive)
  
  if extracted.length() != 2 {
    fail("Should extract 2 files (directories skipped)")
  }
  
  let (name1, content1) = extracted[0]
  let (name2, content2) = extracted[1]
  
  if name1 != "extract1.txt" || content1 != "Content 1" {
    fail("First extracted file should match")
  }
  if name2 != "extract2.txt" || content2 != "Content 2" {
    fail("Second extracted file should match")
  }
}

test "Add symlinks to archive" {
  let archive = @tar.TarArchive::new()
  
  // Add a file and a symlink pointing to it
  archive.add_file("original.txt", "Original content")
  archive.add_symlink("link_to_original", "original.txt")
  archive.add_symlink("another_link", "/path/to/external/file")
  
  if archive.count() != 3 {
    fail("Archive should have 3 entries")
  }
  
  let entries = archive.get_entries()
  
  // Check that the symlinks have correct type
  match entries[1].header.file_type {
    Symlink => ()  // Expected
    _ => fail("Second entry should be a symlink")
  }
  
  match entries[2].header.file_type {
    Symlink => ()  // Expected
    _ => fail("Third entry should be a symlink")
  }
  
  // Check symlink targets are stored in data
  if entries[1].data != "original.txt" {
    fail("Symlink should store target path in data")
  }
  if entries[2].data != "/path/to/external/file" {
    fail("Symlink should store target path in data")
  }
  
  // Check statistics include symlinks
  let stats = archive.get_stats()
  if stats.symlink_count != 2 {
    fail("Should have 2 symlinks in statistics")
  }
  if stats.file_count != 1 {
    fail("Should have 1 regular file")
  }
}

test "Round-trip create and extract" {
  let original_files = [
    ("readme.md", "# My Project"),
    ("main.mbt", "fn main() { println(\"Hello\") }"),
    ("config.json", "{\"version\": \"1.0\"}")
  ]
  
  let archive = @tar.create_simple_archive(original_files)
  let extracted_files = @tar.extract_simple_archive(archive)
  
  if extracted_files.length() != original_files.length() {
    fail("Should extract same number of files")
  }
  
  let mut i = 0
  while i < original_files.length() {
    let (orig_name, orig_content) = original_files[i]
    let (extr_name, extr_content) = extracted_files[i]
    
    if orig_name != extr_name {
      fail("File names should match after round-trip")
    }
    if orig_content != extr_content {
      fail("File contents should match after round-trip")
    }
    
    i = i + 1
  }
}

