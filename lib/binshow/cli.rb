require 'binshow/dump'

module Binshow
  module Cli
    def self.run
      filename = nil
      ARGV.each do |arg|
        filename = arg
      end

      if !filename
        $stderr.puts "No filename specified."
        exit 1
      end

      File.open(filename, 'rb') do |f|
        Binshow.dump_entire_file(f, $stdout, '')
      end
    end
  end
end
