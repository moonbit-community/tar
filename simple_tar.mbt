// Simplified TAR library implementation for MoonBit
// This version focuses on basic functionality with MoonBit-compatible APIs

/// TAR constants
pub const BLOCK_SIZE : Int = 512
pub const HEADER_SIZE : Int = 512

/// File type indicators
pub enum FileType {
  Normal
  Directory
  Symlink
} derive(Eq, Show)

/// Convert FileType to byte
pub fn FileType::to_byte(self : FileType) -> Int {
  match self {
    Normal => 48    // '0'
    Directory => 53 // '5'
    Symlink => 50   // '2'
  }
}

/// Simple TAR header (simplified version)
pub struct SimpleHeader {
  name : String
  size : Int
  file_type : FileType
} derive(Show)

/// TAR entry
pub struct TarEntry {
  header : SimpleHeader
  data : String
} derive(Show)

/// Simple TAR archive
pub struct TarArchive {
  entries : Array[TarEntry]
} derive(Show)

/// Create a new archive
pub fn TarArchive::new() -> TarArchive {
  { entries: [] }
}

/// Add a file to the archive
pub fn TarArchive::add_file(self : TarArchive, name : String, content : String) -> Unit {
  let header = { name, size: content.length(), file_type: Normal }
  let entry = { header, data: content }
  self.entries.push(entry)
}

/// Add a directory to the archive
pub fn TarArchive::add_directory(self : TarArchive, name : String) -> Unit {
  let dir_name = if name.length() > 0 && name[name.length() - 1] == '/' { name } else { name + "/" }
  let header = { name: dir_name, size: 0, file_type: Directory }
  let entry = { header, data: "" }
  self.entries.push(entry)
}

/// Add a symbolic link to the archive
pub fn TarArchive::add_symlink(self : TarArchive, name : String, target : String) -> Unit {
  let header = { name, size: target.length(), file_type: Symlink }
  let entry = { header, data: target }
  self.entries.push(entry)
}

/// Get all entries
pub fn TarArchive::get_entries(self : TarArchive) -> Array[TarEntry] {
  self.entries
}

/// Find an entry by name
pub fn TarArchive::find_entry(self : TarArchive, name : String) -> TarEntry? {
  let mut i = 0
  while i < self.entries.length() {
    if self.entries[i].header.name == name {
      return Some(self.entries[i])
    }
    i = i + 1
  }
  None
}

/// Get entry count
pub fn TarArchive::count(self : TarArchive) -> Int {
  self.entries.length()
}

/// Check if archive is empty
pub fn TarArchive::is_empty(self : TarArchive) -> Bool {
  self.entries.length() == 0
}

/// List all file names
pub fn TarArchive::list_names(self : TarArchive) -> Array[String] {
  let names = []
  let mut i = 0
  while i < self.entries.length() {
    names.push(self.entries[i].header.name)
    i = i + 1
  }
  names
}

/// Get archive statistics
pub struct ArchiveStats {
  total_entries : Int
  file_count : Int
  directory_count : Int
  symlink_count : Int
  total_size : Int
} derive(Show)

/// Get statistics about the archive
pub fn TarArchive::get_stats(self : TarArchive) -> ArchiveStats {
  let mut file_count = 0
  let mut directory_count = 0
  let mut symlink_count = 0
  let mut total_size = 0
  
  let mut i = 0
  while i < self.entries.length() {
    let entry = self.entries[i]
    match entry.header.file_type {
      Normal => {
        file_count = file_count + 1
        total_size = total_size + entry.header.size
      }
      Directory => directory_count = directory_count + 1
      Symlink => {
        symlink_count = symlink_count + 1
        total_size = total_size + entry.header.size
      }
    }
    i = i + 1
  }
  
  {
    total_entries: self.entries.length(),
    file_count,
    directory_count,
    symlink_count,
    total_size
  }
}

/// Create archive from array of (name, content) pairs
pub fn create_simple_archive(files : Array[(String, String)]) -> TarArchive {
  let archive = TarArchive::new()
  let mut i = 0
  while i < files.length() {
    let (name, content) = files[i]
    archive.add_file(name, content)
    i = i + 1
  }
  archive
}

/// Extract all files from archive as (name, content) pairs
pub fn extract_simple_archive(archive : TarArchive) -> Array[(String, String)] {
  let files = []
  let mut i = 0
  while i < archive.entries.length() {
    let entry = archive.entries[i]
    if entry.header.file_type == Normal {
      files.push((entry.header.name, entry.data))
    }
    i = i + 1
  }
  files
}

