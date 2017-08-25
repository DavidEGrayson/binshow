# binshow - explore binary files

*binshow* is not much right now, but eventually it will allow you to explore binary files such as executables, images, and videos, and show the meanings of every byte in such files.

Features that would be nice to have:

- Support for PE and ELF files.
- Support for very large files (lazy loading, pruning of unneeded data)
- A DSL for describing binary formats to make it easier and safer to add support for more formats, or for use outside of binshow.

For now, the binshow prototype will be written in Ruby.  Later, we might switch
to a language like C++ or Rust to make the program faster and easier to distribute.

## Notes

Two important, intertwined views of the data:

- High-level: just enough data to reproduce a file that behaves equivalently.
  This is kind of hard to define, because for a signed file you might need to
  have a copy of all the bytes of a file.
- Medium-level: just enough data to reproduce the file byte-for-byte.
  Same as high-level but might contain offsets, ordering information, and
  meaningless padding / interstitial data.
- Low-level: explains what every byte in the file means