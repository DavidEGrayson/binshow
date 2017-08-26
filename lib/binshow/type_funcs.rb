require 'binshow/format/pe'
require 'binshow/format/unknown_file'

module Binshow
  TypeFuncs = {
    unknown_file: Format::UnknownFile,
    pe_file: Format::Pe::File,
    pe_section_table: Format::Pe::SectionTable,
    pe_section_header: Format::Pe::SectionHeader,
  }
end
