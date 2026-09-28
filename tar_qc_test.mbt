///|
/// Property-based tests for `bobzhang/tar`, driven by
/// `moonbitlang/core/quickcheck`.
///
/// This version of the library is an in-memory archive model: it has no
/// byte-level tar reader or writer (no headers, checksums, 512-byte blocks
/// or streaming), so the properties check the model against a naive
/// reference: a list of `(kind, name, data)` records built from the same
/// sequence of `add_file` / `add_directory` / `add_symlink` calls.

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

///|
fn text_char_gen() -> @qc.Generator[Char] {
  @qc.frequency([
    (10, @qc.char_range('a', 'z')),
    (3, @qc.elements(['/', '.', '-', '_', ' ', '0', '9'])),
    (1, @qc.elements(['\u{0}', '\n', '\t', '\u{7F}'])),
    (2, @qc.elements(['é', 'ß', '中', '文', '\u{FFFD}', '\u{FFFF}'])),
    (2, @qc.elements(['😈', '𝄞', '\u{10000}', '\u{10FFFF}'])),
    (1, @qc.spawn()),
  ])
}

///|
fn text_of_length(n : Int) -> @qc.Generator[String] {
  text_char_gen().array_with_size(n).map(cs => String::from_array(cs))
}

///|
/// Entry names: short paths, names over the 100-byte ustar name field and
/// the 255-byte ustar name + prefix limit, names with trailing slashes,
/// empty names, and names from a small pool (so duplicates occur).
fn name_gen() -> @qc.Generator[String] {
  @qc.frequency([
    (6, @qc.sized(size => @qc.int_range(1, size + 2).flat_map(text_of_length))),
    (2, @qc.int_range(90, 300).flat_map(text_of_length)),
    (
      2,
      @qc.elements([
        "a", "a/", "dir", "dir/", "dir/file.txt", "", "/", ".", "..", "a/b/c/",
      ]),
    ),
    (
      1,
      @qc.elements([
        "p/".repeat(60) + "leaf",
        "x".repeat(100),
        "y".repeat(101),
        "z".repeat(256),
      ]),
    ),
  ])
}

///|
/// File contents / symlink targets: empty, small, unicode and a few KB.
fn content_gen() -> @qc.Generator[String] {
  @qc.frequency([
    (2, @qc.pure("")),
    (
      6,
      @qc.sized(size => @qc.int_range(0, size * 4 + 1).flat_map(text_of_length)),
    ),
    (1, @qc.int_range(1000, 5000).flat_map(text_of_length)),
    (1, @qc.int_range(512, 513).map(n => "b".repeat(n))),
  ])
}

///|
priv enum Op {
  File(String, String)
  Dir(String)
  Link(String, String)
} derive(Debug)

///|
fn op_gen() -> @qc.Generator[Op] {
  @qc.frequency([
    (5, name_gen().zip(content_gen()).map(p => Op::File(p.0, p.1))),
    (2, name_gen().map(n => Op::Dir(n))),
    (2, name_gen().zip(name_gen()).map(p => Op::Link(p.0, p.1))),
  ])
}

///|
impl @qc.Shrink for Op with fn shrink(self) {
  match self {
    File(n, d) => @qc.Shrink::shrink((n, d)).map(p => Op::File(p.0, p.1))
    Dir(n) => @qc.Shrink::shrink(n).map(n => Op::Dir(n))
    Link(n, t) => @qc.Shrink::shrink((n, t)).map(p => Op::Link(p.0, p.1))
  }
}

///|
/// A sequence of archive-building calls.
priv struct Ops {
  ops : Array[Op]
} derive(Debug)

///|
impl @qc.Arbitrary for Ops with fn arbitrary(size, rs) {
  let gen = @qc.sized(size => {
    @qc.int_range(0, size + 1).flat_map(n => op_gen().array_with_size(n))
  })
  { ops: gen.run(size, rs), }
}

///|
impl @qc.Shrink for Ops with fn shrink(self) {
  @qc.Shrink::shrink(self.ops).map(ops => { ops, })
}

///|
/// A list of `(name, content)` pairs for `create_simple_archive`.
priv struct Files {
  files : Array[(String, String)]
} derive(Debug)

///|
impl @qc.Arbitrary for Files with fn arbitrary(size, rs) {
  let gen = @qc.sized(size => {
    @qc.int_range(0, size + 1).flat_map(n => {
      name_gen().zip(content_gen()).array_with_size(n)
    })
  })
  { files: gen.run(size, rs), }
}

///|
impl @qc.Shrink for Files with fn shrink(self) {
  @qc.Shrink::shrink(self.files).map(files => { files, })
}

// ---------------------------------------------------------------------------
// Reference model
// ---------------------------------------------------------------------------

///|
/// What an entry should look like: kind as a ustar typeflag, name, data.
priv struct Expected {
  kind : Char
  name : String
  data : String
} derive(Eq)

///|
fn expected_entries(ops : Array[Op]) -> Array[Expected] {
  ops.map(op => {
    match op {
      File(name, data) => { kind: '0', name, data, }
      Dir(name) =>
        {
          kind: '5',
          name: if name.has_suffix("/") {
            name
          } else {
            name + "/"
          },
          data: "",
        }
      Link(name, target) => { kind: '2', name, data: target, }
    }
  })
}

///|
fn build(ops : Array[Op]) -> @tar.TarArchive {
  let archive = @tar.TarArchive::new()
  for op in ops {
    match op {
      File(name, data) => archive.add_file(name, data)
      Dir(name) => archive.add_directory(name)
      Link(name, target) => archive.add_symlink(name, target)
    }
  }
  archive
}

///|
fn actual_entries(archive : @tar.TarArchive) -> Array[Expected] {
  archive
  .get_entries()
  .map(e => {
    kind: Int::unsafe_to_char(e.header.file_type.to_byte()),
    name: e.header.name,
    data: e.data,
  })
}

///|
fn is_ascii(s : String) -> Bool {
  s.iter().all(c => c.to_int() < 0x80)
}

///|
fn utf8_length(s : String) -> Int {
  let mut n = 0
  for c in s {
    let x = c.to_int()
    n += if x < 0x80 {
      1
    } else if x < 0x800 {
      2
    } else if x < 0x10000 {
      3
    } else {
      4
    }
  }
  n
}

///|
fn ops_observations(ops : Ops) -> Array[@qc.Observation] {
  let names = ops.ops.map(op => {
    match op {
      File(n, _) | Dir(n) | Link(n, _) => n
    }
  })
  let seen : Map[String, Unit] = Map([])
  let mut dup = false
  for n in names {
    if seen.contains(n) {
      dup = true
    }
    seen[n] = ()
  }
  [
    @qc.classify(ops.ops.is_empty(), "empty archive"),
    @qc.classify(dup, "duplicate names"),
    @qc.classify(
      names.iter().any(n => utf8_length(n) > 100),
      "name > 100 bytes",
    ),
    @qc.classify(
      names.iter().any(n => utf8_length(n) > 255),
      "name > 255 bytes",
    ),
    @qc.classify(names.iter().any(n => !is_ascii(n)), "non-ASCII name"),
    @qc.classify(ops.ops.iter().any(op => op is Dir(_)), "has directory"),
    @qc.classify(ops.ops.iter().any(op => op is Link(_, _)), "has symlink"),
    @qc.classify(
      ops.ops.iter().any(op => op is File(_, d) && d.length() >= 1000),
      "file >= 1000 chars",
    ),
    @qc.classify(ops.ops.iter().any(op => op is File(_, "")), "empty file"),
  ]
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

///|
test "qc: entries record every add call in order, with the right kind and data" {
  @qc.check(
    (ops : Ops) => {
      let archive = build(ops.ops)
      actual_entries(archive) == expected_entries(ops.ops)
    },
    observe=ops_observations,
    count=300,
    seed=0x7a2_0001,
  )
}

///|
test "qc: count / is_empty / list_names agree with the entries" {
  @qc.check(
    (ops : Ops) => {
      let archive = build(ops.ops)
      let expected = expected_entries(ops.ops)
      archive.count() == expected.length() &&
      archive.is_empty() == expected.is_empty() &&
      archive.list_names() == expected.map(e => e.name) &&
      archive.entries.length() == archive.get_entries().length()
    },
    seed=0x7a2_0002,
  )
}

///|
test "qc: header size is the payload length; directories are empty" {
  @qc.check(
    (ops : Ops) => {
      let archive = build(ops.ops)
      archive
      .get_entries()
      .iter()
      .all(e => {
        match e.header.file_type {
          Directory => e.header.size == 0 && e.data == ""
          Normal | Symlink =>
            e.header.size == e.data.length() &&
            // for ASCII the size is also the byte count a tar header records
            (!is_ascii(e.data) || e.header.size == utf8_length(e.data))
        }
      })
    },
    seed=0x7a2_0003,
  )
}

///|
test "qc: directory names get exactly one trailing slash, idempotently" {
  @qc.check(
    (name : String) => {
      let a = @tar.TarArchive::new()
      a.add_directory(name)
      let stored = a.list_names()[0]
      let b = @tar.TarArchive::new()
      b.add_directory(stored)
      stored.has_suffix("/") &&
      (stored == name || stored == name + "/") &&
      b.list_names()[0] == stored
    },
    seed=0x7a2_0004,
  )
}

///|
test "qc: extract_simple_archive returns the regular files in order" {
  @qc.check(
    (ops : Ops) => {
      let extracted = @tar.extract_simple_archive(build(ops.ops))
      let expected = expected_entries(ops.ops)
        .filter(e => e.kind == '0')
        .map(e => (e.name, e.data))
      extracted == expected
    },
    seed=0x7a2_0005,
  )
}

///|
test "qc: extract_simple_archive inverts create_simple_archive" {
  @qc.check(
    (files : Files) => {
      let archive = @tar.create_simple_archive(files.files)
      @tar.extract_simple_archive(archive) == files.files &&
      archive.count() == files.files.length() &&
      archive.get_stats().file_count == files.files.length()
    },
    observe=files => {
      [
        @qc.classify(files.files.is_empty(), "no files"),
        @qc.classify(
          files.files.iter().any(f => utf8_length(f.0) > 100),
          "name > 100 bytes",
        ),
      ]
    },
    seed=0x7a2_0006,
  )
}

///|
test "qc: get_stats agrees with the entries" {
  @qc.check(
    (ops : Ops) => {
      let archive = build(ops.ops)
      let stats = archive.get_stats()
      let expected = expected_entries(ops.ops)
      let count = (k : Char) => expected.filter(e => e.kind == k).length()
      let size = expected.fold(init=0, (acc, e) => acc + e.data.length())
      stats.total_entries == expected.length() &&
      stats.file_count == count('0') &&
      stats.directory_count == count('5') &&
      stats.symlink_count == count('2') &&
      stats.total_entries ==
      stats.file_count + stats.directory_count + stats.symlink_count &&
      stats.total_size == size
    },
    seed=0x7a2_0007,
  )
}

///|
test "qc: find_entry returns the first entry with that name, or None" {
  @qc.check(
    (input : (Ops, String)) => {
      let (ops, probe) = input
      let archive = build(ops.ops)
      let expected = expected_entries(ops.ops)
      let probes = expected.map(e => e.name)
      probes.push(probe)
      probes
      .iter()
      .all(name => {
        let reference = expected.search_by(e => e.name == name)
        match (archive.find_entry(name), reference) {
          (None, None) => true
          (Some(entry), Some(i)) =>
            entry.header.name == name &&
            physical_equal(entry, archive.entries[i])
          _ => false
        }
      })
    },
    seed=0x7a2_0008,
  )
}

///|
test "qc: adding entries never changes the earlier ones" {
  @qc.check(
    (input : (Ops, Ops)) => {
      let (first, second) = input
      let archive = build(first.ops)
      let before = actual_entries(archive)
      for op in second.ops {
        match op {
          File(name, data) => archive.add_file(name, data)
          Dir(name) => archive.add_directory(name)
          Link(name, target) => archive.add_symlink(name, target)
        }
      }
      let after = actual_entries(archive)
      after.length() == before.length() + second.ops.length() &&
      after[:before.length()].to_owned() == before &&
      after == expected_entries(first.ops + second.ops)
    },
    count=200,
    seed=0x7a2_0009,
  )
}

///|
test "qc: FileType::to_byte gives the ustar typeflags" {
  @qc.check(
    (ops : Ops) => {
      build(ops.ops)
      .get_entries()
      .iter()
      .all(e => {
        let b = e.header.file_type.to_byte()
        match e.header.file_type {
          Normal => b == '0'.to_int()
          Directory => b == '5'.to_int()
          Symlink => b == '2'.to_int()
        }
      })
    },
    count=50,
    seed=0x7a2_000a,
  )
}
