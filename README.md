# binshow - explore binary files

*binshow* is not much right now, but eventually it will allow you to explore binary files such as executables, images, and videos, and show the meanings of every byte in such files.

Features that would be nice to have:

- Core:
  - Converts a binary file to a data structure that is easy to show to humans.
  - Works efficiently with very large files and pathological files.
    - Supports lazily-loading parts of the data structure.
    - Indivisible load operations should always be O(ln(N)) or less.
    - Supports freeing unneeded parts of the data structure (garbage collection).
  - Supports iterating through the data in heirarchical order or file order.
  - For a given byte offset or set of offsets, can locate its position in the
    heirarchy efficiently (might be O(N) for some file formats).
  - Nothing is obscured: the human-readable form always has enough information
    to reproduce the file byte-for-byte.
- Support for PE and ELF files.
- A DSL for describing binary formats to make it easier and safer to add support for more formats, or for use outside of binshow.

For now, the binshow prototype will be written in Ruby.  Later, we might switch
to a language like C++ or Rust to make the program faster and easier to distribute.

