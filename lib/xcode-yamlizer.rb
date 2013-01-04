# encoding: UTF-8
require 'xcode-yamlizer/version'
require 'xcode-yamlizer/dumpers'

$KCODE = 'UTF8' unless RUBY_VERSION >= '1.9'
require 'pp'


YAML_FORMATS = [".yaml", ".yml"]
PLIST_FORMATS = [".pbxproj"]
XML_FORMATS = [".xib", ".storyboard", /(.*).xcdatamodeld\/(.*).xcdatamodel\/contents/]


XCODE_FORMATS = PLIST_FORMATS + XML_FORMATS


DUMPERS = [
  [YAML_FORMATS, YamlDumper],
  [PLIST_FORMATS, PlistDumper],
  [XML_FORMATS, XmlDumper],
]


module Enumerable
  def include_filename?(filename)
    self.each do |elem|
      if elem.kind_of? Regexp and filename =~ elem
        return true
      end
    end
    return self.include? File.extname(filename)
  end
end

def dumper_for_filename(filename)
  DUMPERS.each do |formats, dumper|
    if formats.include_filename? filename
      return dumper.new(filename)
    end
  end
  return nil
end


def dump(output, object)
  dumper = dumper_for_filename(output)
  if dumper
    dumper.dump(object)
  end
end
def load(input)
  dumper = dumper_for_filename(input)
  if dumper
    return dumper.load()
  end
end



module XcodeYamlizer
  def self.convert_directory(dir, to_xcode)
    puts "Conventering directory '#{dir}'..."
    files = []
    formats = to_xcode ? YAML_FORMATS : XCODE_FORMATS

    Dir.glob(dir+"**/*").each do |filename|
      if formats.include_filename? filename
        files += [filename]
    
      end
    end
    
    puts "Found:"
    puts files
    files.each do |file|
      convert_file file
    end
    puts "Finished!"
  end

  def self.convert_file(input)
    result = nil
    if YAML_FORMATS.include_filename? input
      output = input.chomp(File.extname(input))
    elsif XCODE_FORMATS.include_filename? input
      output = "#{input}.yaml"

    end
    result = load(input)
    dump(output, result)
    if result
      puts "#{input} => #{output}"
      return output
    else
      puts "Don't know what to do with '#{input}'"
    end
  end

  def self.root
    return File.expand_path('../..', __FILE__)
  end

  def self.run_pre_commit
    convert_directory(File.expand_path('./')+"/", false)
  end
end


