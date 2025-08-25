// Minimal test to check basic functionality

test "Create archive" {
  let archive = @tar.TarArchive::new()
  if !archive.is_empty() {
    fail("New archive should be empty")
  }
}

test "Add file" {
  let archive = @tar.TarArchive::new()
  archive.add_file("test.txt", "Hello")
  if archive.count() != 1 {
    fail("Archive should have 1 entry")
  }
}

test "Create from files" {
  let files = [("a.txt", "A"), ("b.txt", "B")]
  let archive = @tar.create_simple_archive(files)
  if archive.count() != 2 {
    fail("Archive should have 2 entries")
  }
}

