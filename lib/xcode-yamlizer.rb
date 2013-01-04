# encoding: UTF-8
$KCODE = 'UTF8' unless RUBY_VERSION >= '1.9'
require 'ya2yaml'
require 'json'

require 'osx/plist'
require 'yaml'
require 'args_parser'
require 'pp'
require 'cobravsmongoose'


YAML_FORMATS = [".yaml", ".yml"]
PLIST_FORMATS = [".pbxproj"]
XML_FORMATS = [".xib", ".storyboard", /(.*).xcdatamodeld\/(.*).xcdatamodel\/contents/]


XCODE_FORMATS = PLIST_FORMATS + XML_FORMATS

parser = ArgsParser.parse ARGV do
  arg :input, 'convert file (autodetects direction)', :alias => :i
  arg :dir, 'convert directory (default direction - from XCode to YAML)', :alias => :d
  arg :to_xcode, 'direction: from YAML to XCode format'
  arg :verbose, 'verbose mode'
  arg :help, 'show help', :alias => :h
  validate :input, "invalid file" do |v|
    File.exist?(v)
  end
end

if parser.has_option? :help \
    or (!parser.has_param?(:input) and !parser.has_param? :dir) \
    or (parser.has_param?(:input) and parser.has_param?(:dir))
  STDERR.puts parser.help
  exit 1
end


class Dumper
  def initialize(filename)
    @filename = filename
  end

  def dump(object)
  end
  def load()
  end
end

class PlistDumper < Dumper
  def dump(object)
    OSX::PropertyList.dump_file(@filename, object, :xml1)
  end
  def load()
    return OSX::PropertyList.load_file(@filename)
  end
end

class YamlDumper < Dumper
  def dump(object)
    result = YAML::dump(object)
    if result
      File.open(@filename, 'w') do |f|
        f.write(result)
        #f.write(object.ya2yaml(:syck_compatible => false))
      end
    end
  end

  def _hash_clean(obj)
    if obj.respond_to?(:key?) && obj.key?(nil)
      obj.delete(nil)
    end
    if obj.respond_to?(:each)
      obj.find{ |*a| _hash_clean(a.last) }
    end
  end
  def load()
    result = YAML::load_file(@filename)
    _hash_clean(result)
    return result
  end
end

class XmlDumper < Dumper
  def dump(object)
    result =  CobraVsMongoose.hash_to_xml(object)
    if result
      File.open(@filename, 'w') do |f|
        f.write result
      end
    end
  end
  def load()
    return CobraVsMongoose.xml_to_hash(IO.read(@filename))
  end
end


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


def convert_file(input)
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




if parser.has_param? :input
  convert_file parser[:input]
end


def convert_directory(dir, to_xcode)
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

if parser.has_param? :dir
  convert_directory parser[:dir], parser.has_option?(:to_xcode)
end
