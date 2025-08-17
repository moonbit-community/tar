// Comprehensive tests for the TAR library

test "FileType conversion" {
  // Test FileType to byte conversion
  if @lib.FileType::Normal.to_byte() != b'0' {
    fail("Normal file type should convert to '0'")
  }
  if @lib.FileType::Directory.to_byte() != b'5' {
    fail("Directory file type should convert to '5'")
  }
  if @lib.FileType::Symlink.to_byte() != b'2' {
    fail("Symlink file type should convert to '2'")
  }
  
  // Test byte to FileType conversion
  match @lib.FileType::from_byte(b'0') {
    Some(@lib.FileType::Normal) => ()
    _ => fail("Byte '0' should convert to Normal")
  }
  
  match @lib.FileType::from_byte(b'5') {
    Some(@lib.FileType::Directory) => ()
    _ => fail("Byte '5' should convert to Directory")
  }
  
  match @lib.FileType::from_byte(b'9') {
    None => ()
    _ => fail("Invalid byte should return None")
  }
}

test "Header creation and serialization" {
  let header = @lib.Header::new()
  
  // Test default values
  if header.file_mode != 0o644 {
    fail("Default file mode should be 0o644")
  }
  if header.file_type != @lib.FileType::Normal {
    fail("Default file type should be Normal")
  }
  if header.magic != @lib.USTAR_MAGIC {
    fail("Default magic should be ustar")
  }
  
  // Test serialization and deserialization
  let header_bytes = header.to_bytes()
  if header_bytes.length() != @lib.HEADER_SIZE {
    fail("Header bytes should be exactly 512 bytes")
  }
  
  match @lib.Header::from_bytes(header_bytes) {
    Ok(parsed_header) => {
      if parsed_header.file_mode != header.file_mode {
        fail("Parsed header should have same file mode")
      }
      if parsed_header.magic != header.magic {
        fail("Parsed header should have same magic")
      }
    }
    Err(_) => fail("Should be able to parse serialized header")
  }
}

test "Archive creation and reading" {
  // Create a simple archive
  let archive = @lib.Archive::new()
  
  // Add some files
  match archive.add_file("test.txt", "Hello, world!") {
    Ok(()) => ()
    Err(_) => fail("Should be able to add file to archive")
  }
  
  match archive.add_file("another.txt", "Another file") {
    Ok(()) => ()
    Err(_) => fail("Should be able to add second file to archive")
  }
  
  match archive.add_directory("subdir") {
    Ok(()) => ()
    Err(_) => fail("Should be able to add directory to archive")
  }
  
  // Get archive bytes
  let archive_bytes = archive.to_bytes()
  if archive_bytes.length() == 0 {
    fail("Archive should not be empty")
  }
  
  // Read the archive back
  let reader = @lib.Reader::from_bytes(archive_bytes)
  
  match reader.list_entries() {
    Ok(entries) => {
      if entries.length() != 3 {
        fail("Should have 3 entries in archive")
      }
      
      // Check first entry
      let first_entry = entries[0]
      if first_entry.full_name() != "test.txt" {
        fail("First entry should be test.txt")
      }
      if first_entry.file_type != @lib.FileType::Normal {
        fail("First entry should be a normal file")
      }
      
      // Check directory entry
      let dir_entry = entries[2]
      if dir_entry.full_name() != "subdir/" {
        fail("Directory entry should end with /")
      }
      if dir_entry.file_type != @lib.FileType::Directory {
        fail("Directory entry should have Directory type")
      }
    }
    Err(_) => fail("Should be able to list entries")
  }
}

test "File extraction" {
  // Create archive with test data
  let files = [("file1.txt", "Content 1"), ("file2.txt", "Content 2")]
  
  match @lib.create_archive(files) {
    Ok(archive_bytes) => {
      match @lib.extract_archive(archive_bytes) {
        Ok(extracted_files) => {
          if extracted_files.length() != 2 {
            fail("Should extract 2 files")
          }
          
          let (name1, content1) = extracted_files[0]
          if name1 != "file1.txt" || content1 != "Content 1" {
            fail("First file should match original")
          }
          
          let (name2, content2) = extracted_files[1]
          if name2 != "file2.txt" || content2 != "Content 2" {
            fail("Second file should match original")
          }
        }
        Err(_) => fail("Should be able to extract files")
      }
    }
    Err(_) => fail("Should be able to create archive")
  }
}

test "Archive listing" {
  let files = [("a.txt", "A"), ("b.txt", "B"), ("c.txt", "C")]
  
  match @lib.create_archive(files) {
    Ok(archive_bytes) => {
      match @lib.list_archive(archive_bytes) {
        Ok(file_names) => {
          if file_names.length() != 3 {
            fail("Should list 3 files")
          }
          if file_names[0] != "a.txt" {
            fail("First file should be a.txt")
          }
          if file_names[1] != "b.txt" {
            fail("Second file should be b.txt")
          }
          if file_names[2] != "c.txt" {
            fail("Third file should be c.txt")
          }
        }
        Err(_) => fail("Should be able to list files")
      }
    }
    Err(_) => fail("Should be able to create archive")
  }
}

test "Archive validation" {
  let files = [("valid.txt", "Valid content")]
  
  match @lib.create_archive(files) {
    Ok(archive_bytes) => {
      match @lib.validate_archive(archive_bytes) {
        Ok(()) => ()  // Success
        Err(_) => fail("Valid archive should pass validation")
      }
    }
    Err(_) => fail("Should be able to create archive")
  }
}

test "Empty archive" {
  let archive = @lib.Archive::new()
  if !archive.is_empty() {
    fail("New archive should be empty")
  }
  
  let archive_bytes = archive.to_bytes()
  let reader = @lib.Reader::from_bytes(archive_bytes)
  
  match reader.list_entries() {
    Ok(entries) => {
      if entries.length() != 0 {
        fail("Empty archive should have no entries")
      }
    }
    Err(_) => fail("Should be able to list entries in empty archive")
  }
}

test "Large file names" {
  let archive = @lib.Archive::new()
  
  // Test normal length name
  match archive.add_file("normal_name.txt", "content") {
    Ok(()) => ()
    Err(_) => fail("Should handle normal file names")
  }
  
  // Test long name that should be split
  let long_name = "very/long/path/with/many/directories/and/a/very/long/filename_that_exceeds_normal_limits.txt"
  match archive.add_file(long_name, "content") {
    Ok(()) => ()
    Err(_) => fail("Should handle long file names by splitting")
  }
}

test "Different file types" {
  let archive = @lib.Archive::new()
  
  // Add regular file
  match archive.add_file("regular.txt", "content") {
    Ok(()) => ()
    Err(_) => fail("Should add regular file")
  }
  
  // Add directory
  match archive.add_directory("testdir") {
    Ok(()) => ()
    Err(_) => fail("Should add directory")
  }
  
  // Add symlink
  match archive.add_symlink("link", "target") {
    Ok(()) => ()
    Err(_) => fail("Should add symlink")
  }
  
  let archive_bytes = archive.to_bytes()
  let reader = @lib.Reader::from_bytes(archive_bytes)
  
  match reader.list_entries() {
    Ok(entries) => {
      if entries.length() != 3 {
        fail("Should have 3 entries")
      }
      
      if entries[0].file_type != @lib.FileType::Normal {
        fail("First entry should be normal file")
      }
      if entries[1].file_type != @lib.FileType::Directory {
        fail("Second entry should be directory")
      }
      if entries[2].file_type != @lib.FileType::Symlink {
        fail("Third entry should be symlink")
      }
    }
    Err(_) => fail("Should list entries")
  }
}

test "Archive statistics" {
  let archive = @lib.Archive::new()
  
  // Add various types of entries
  match archive.add_file("file1.txt", "Hello") {
    Ok(()) => ()
    Err(_) => fail("Should add file")
  }
  
  match archive.add_file("file2.txt", "World!") {
    Ok(()) => ()
    Err(_) => fail("Should add file")
  }
  
  match archive.add_directory("dir1") {
    Ok(()) => ()
    Err(_) => fail("Should add directory")
  }
  
  match archive.add_symlink("link1", "file1.txt") {
    Ok(()) => ()
    Err(_) => fail("Should add symlink")
  }
  
  let archive_bytes = archive.to_bytes()
  let reader = @lib.Reader::from_bytes(archive_bytes)
  
  match reader.get_stats() {
    Ok(stats) => {
      if stats.entry_count != 4 {
        fail("Should have 4 entries total")
      }
      if stats.file_count != 2 {
        fail("Should have 2 regular files")
      }
      if stats.directory_count != 1 {
        fail("Should have 1 directory")
      }
      if stats.symlink_count != 1 {
        fail("Should have 1 symlink")
      }
      if stats.total_size != 11L {  // "Hello" (5) + "World!" (6) = 11
        fail("Total size should be 11 bytes")
      }
    }
    Err(_) => fail("Should get archive statistics")
  }
}
