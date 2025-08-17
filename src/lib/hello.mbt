// TAR file format constants and structures
// Based on POSIX.1-1988 (ustar) format

/// TAR header block size (512 bytes)
pub const BLOCK_SIZE : Int = 512

/// TAR header size (512 bytes)
pub const HEADER_SIZE : Int = 512

/// Magic number for ustar format
pub const USTAR_MAGIC : String = "ustar"

/// Version for ustar format
pub const USTAR_VERSION : String = "00"

/// File type indicators
pub enum FileType {
  /// Regular file
  Normal
  /// Hard link
  Link
  /// Symbolic link
  Symlink
  /// Character special
  Char
  /// Block special
  Block
  /// Directory
  Directory
  /// FIFO
  Fifo
  /// Reserved
  Reserved
} derive(Eq, Show)

/// Convert FileType to byte representation
pub fn FileType::to_byte(self : FileType) -> Byte {
  match self {
    Normal => b'0'
    Link => b'1'
    Symlink => b'2'
    Char => b'3'
    Block => b'4'
    Directory => b'5'
    Fifo => b'6'
    Reserved => b'7'
  }
}

/// Convert byte to FileType
pub fn FileType::from_byte(b : Byte) -> FileType? {
  match b {
    b'0' | 0 => Some(Normal)  // '\0' is also treated as normal file
    b'1' => Some(Link)
    b'2' => Some(Symlink)
    b'3' => Some(Char)
    b'4' => Some(Block)
    b'5' => Some(Directory)
    b'6' => Some(Fifo)
    b'7' => Some(Reserved)
    _ => None
  }
}

/// TAR header structure (512 bytes total)
pub struct Header {
  /// File name (100 bytes, null-terminated)
  file_name : String
  /// File mode (8 bytes, octal)
  file_mode : Int
  /// Owner user ID (8 bytes, octal)
  user_id : Int
  /// Owner group ID (8 bytes, octal)
  group_id : Int
  /// File size in bytes (12 bytes, octal)
  file_size : Int64
  /// Last modification time (12 bytes, octal, Unix timestamp)
  mod_time : Int64
  /// Header checksum (8 bytes, octal)
  checksum : Int
  /// File type indicator (1 byte)
  file_type : FileType
  /// Name of linked file (100 bytes, null-terminated)
  link_name : String
  /// Magic number "ustar" (6 bytes)
  magic : String
  /// Version "00" (2 bytes)
  version : String
  /// Owner user name (32 bytes, null-terminated)
  user_name : String
  /// Owner group name (32 bytes, null-terminated)
  group_name : String
  /// Device major number (8 bytes, octal)
  dev_major : Int
  /// Device minor number (8 bytes, octal)
  dev_minor : Int
  /// Filename prefix (155 bytes, null-terminated)
  prefix : String
} derive(Show)

/// Create a new header with default values
pub fn Header::new() -> Header {
  {
    file_name: "",
    file_mode: 0o644,
    user_id: 0,
    group_id: 0,
    file_size: 0L,
    mod_time: 0L,
    checksum: 0,
    file_type: Normal,
    link_name: "",
    magic: USTAR_MAGIC,
    version: USTAR_VERSION,
    user_name: "",
    group_name: "",
    dev_major: 0,
    dev_minor: 0,
    prefix: ""
  }
}

/// Error types for TAR operations
pub enum TarError {
  /// Invalid header format
  InvalidHeader(String)
  /// Invalid checksum
  InvalidChecksum
  /// File too large
  FileTooLarge
  /// Invalid file name
  InvalidFileName(String)
  /// IO error
  IOError(String)
  /// Unsupported feature
  Unsupported(String)
} derive(Eq, Show)

/// Result type for TAR operations
pub typealias Result[T, TarError] as TarResult[T]
