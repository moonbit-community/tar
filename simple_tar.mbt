// Simplified TAR library implementation for MoonBit
// This version focuses on basic functionality with MoonBit-compatible APIs

///|
/// TAR constants
pub const BLOCK_SIZE : Int = 512

///|
pub const HEADER_SIZE : Int = 512

///|
/// File type indicators
pub enum FileType {
  Normal
  Directory
  Symlink
} derive(Eq, Show)

///|
/// Convert FileType to byte
pub fn FileType::to_byte(self : FileType) -> Int {
  match self {
    Normal => 48 // '0'
    Directory => 53 // '5'
    Symlink => 50 // '2'
  }
}

///|
/// Simple TAR header (simplified version)
pub struct SimpleHeader {
  name : String
  size : Int
  file_type : FileType
} derive(Show)

///|
/// TAR entry
pub struct TarEntry {
  header : SimpleHeader
  data : String
} derive(Show)

///|
/// Simple TAR archive
pub struct TarArchive {
  entries : Array[TarEntry]
} derive(Show)

///|
/// Create a new archive
pub fn TarArchive::new() -> TarArchive {
  { entries: [] }
}

///|
/// Add a file to the archive
pub fn TarArchive::add_file(
  self : TarArchive,
  name : String,
  content : String,
) -> Unit {
  let header = { name, size: content.length(), file_type: Normal }
  let entry = { header, data: content }
  self.entries.push(entry)
}

///|
/// Add a directory to the archive
pub fn TarArchive::add_directory(self : TarArchive, name : String) -> Unit {
  let dir_name = if name.length() > 0 && name[name.length() - 1] == '/' {
    name
  } else {
    name + "/"
  }
  let header = { name: dir_name, size: 0, file_type: Directory }
  let entry = { header, data: "" }
  self.entries.push(entry)
}

///|
/// Add a symbolic link to the archive
pub fn TarArchive::add_symlink(
  self : TarArchive,
  name : String,
  target : String,
) -> Unit {
  let header = { name, size: target.length(), file_type: Symlink }
  let entry = { header, data: target }
  self.entries.push(entry)
}

///|
/// Get all entries
pub fn TarArchive::get_entries(self : TarArchive) -> Array[TarEntry] {
  self.entries
}

///|
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

///|
/// Get entry count
pub fn TarArchive::count(self : TarArchive) -> Int {
  self.entries.length()
}

///|
/// Check if archive is empty
pub fn TarArchive::is_empty(self : TarArchive) -> Bool {
  self.entries.is_empty()
}

///|
fn slice_bytes(bytes : Bytes, start : Int, len : Int) -> Bytes {
  let res = FixedArray::make(len, b'\x00')
  for i = 0; i < len; i = i + 1 {
    res[i] = bytes[start + i]
  }
  Bytes::from_array(res)
}

///|
fn bytes_to_string(bytes : Bytes) -> String {
  @utf8.decode(bytes) catch {
    _ => ""
  }
}

///|
fn read_cstring(bytes : Bytes, start : Int, len : Int) -> String {
  let mut end = 0
  while end < len && bytes[start + end] != b'\x00' {
    end = end + 1
  }
  bytes_to_string(slice_bytes(bytes, start, end))
}

///|
fn parse_octal(bytes : Bytes, start : Int, len : Int) -> Int {
  let mut value = 0
  let mut i = 0
  while i < len {
    let b = bytes[start + i]
    if b == b'\x00' || b == b' ' {
      break
    }
    let d = b.to_int() - '0'.to_int()
    if d < 0 || d > 7 {
      break
    }
    value = value * 8 + d
    i = i + 1
  }
  value
}

///|
fn write_octal(
  buf : FixedArray[Byte],
  start : Int,
  len : Int,
  value : Int,
) -> Unit {
  let mut i = 0
  while i < len {
    buf[start + i] = b'0'
    i = i + 1
  }
  let mut v = value
  let digits : Array[Byte] = []
  if v == 0 {
    digits.push(b'0')
  } else {
    while v > 0 {
      let d = v % 8
      digits.push(('0'.to_int() + d).to_byte())
      v = v / 8
    }
  }
  let mut pos = len - 2
  let mut idx = 0
  while pos >= 0 && idx < digits.length() {
    buf[start + pos] = digits[idx]
    pos = pos - 1
    idx = idx + 1
  }
  buf[start + len - 1] = b'\x00'
}

///|
fn is_zero_block(bytes : Bytes, offset : Int) -> Bool {
  if offset + BLOCK_SIZE > bytes.length() {
    return true
  }
  for i = 0; i < BLOCK_SIZE; i = i + 1 {
    if bytes[offset + i] != b'\x00' {
      return false
    }
  }
  true
}

///|
pub fn TarArchive::from_bytes(bytes : Bytes) -> TarArchive {
  let archive = TarArchive::new()
  let mut offset = 0
  while offset + BLOCK_SIZE <= bytes.length() && !is_zero_block(bytes, offset) {
    let name = read_cstring(bytes, offset, 100)
    let size = parse_octal(bytes, offset + 124, 12)
    let type_byte = bytes[offset + 156]
    let file_type = match type_byte {
      b'5' => Directory
      b'2' => Symlink
      _ => Normal
    }
    let data_offset = offset + HEADER_SIZE
    let data_len = if data_offset + size <= bytes.length() { size } else { 0 }
    let data = if file_type == Directory || data_len == 0 {
      if file_type == Symlink {
        read_cstring(bytes, offset + 157, 100)
      } else {
        ""
      }
    } else {
      bytes_to_string(slice_bytes(bytes, data_offset, data_len))
    }
    let header = { name, size, file_type }
    archive.entries.push({ header, data })
    let padded = if size == 0 {
      0
    } else {
      (size + BLOCK_SIZE - 1) / BLOCK_SIZE * BLOCK_SIZE
    }
    offset = data_offset + padded
  }
  archive
}

///|
pub fn TarArchive::to_bytes(self : TarArchive) -> Bytes {
  let buf = @buffer.new()
  for entry in self.entries {
    let header = FixedArray::make(HEADER_SIZE, b'\x00')
    let name_bytes = @utf8.encode(entry.header.name)
    let name_len = if name_bytes.length() > 100 {
      100
    } else {
      name_bytes.length()
    }
    for i = 0; i < name_len; i = i + 1 {
      header[i] = name_bytes[i]
    }
    let data_bytes = @utf8.encode(entry.data)
    let data_len = if entry.header.file_type == Directory {
      0
    } else {
      data_bytes.length()
    }
    write_octal(header, 124, 12, data_len)
    header[156] = entry.header.file_type.to_byte().to_byte()
    buf.write_bytes(Bytes::from_array(header))
    if data_len > 0 {
      buf.write_bytes(data_bytes)
      let padding = (BLOCK_SIZE - data_len % BLOCK_SIZE) % BLOCK_SIZE
      if padding > 0 {
        let pad = FixedArray::make(padding, b'\x00')
        buf.write_bytes(Bytes::from_array(pad))
      }
    }
  }
  let end = FixedArray::make(BLOCK_SIZE * 2, b'\x00')
  buf.write_bytes(Bytes::from_array(end))
  buf.to_bytes()
}

///|
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

///|
/// Get archive statistics
pub struct ArchiveStats {
  total_entries : Int
  file_count : Int
  directory_count : Int
  symlink_count : Int
  total_size : Int
} derive(Show)

///|
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
    total_size,
  }
}

///|
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

///|
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
