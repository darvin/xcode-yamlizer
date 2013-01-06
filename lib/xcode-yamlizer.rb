# encoding: UTF-8
require 'xcode-yamlizer/version'
require 'xcode-yamlizer/dumpers'
require 'rugged'
require 'pathname'


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



def repo_add_files(files)
  repo_dir = '.'
  repo = Rugged::Repository.new(repo_dir)
  index = repo.index
  files.each do |file|
    if not index.get_entry(file)
      #puts "Adding: #{file}"
      index.add(file)
    end
  end
  index.write()
end

def repo_remove_files(files)
  repo_dir = '.'
  repo = Rugged::Repository.new(repo_dir)
  index = repo.index
  files.each do |file|
    if index.get_entry(file)
      #puts "Removing: #{file}"
      index.remove(file)
    end
  end
  index.write()
end

def repo_gitignore_add_files(files)
  begin
    already_ignored = IO.foreach(".gitignore").map do |line|
      line.chomp
    end
  rescue Errno::ENOENT
    already_ignored = []
  end
  

  new_ignored = files - already_ignored

  if new_ignored.count > 0
    File.open(".gitignore", "a") do |f|
      f.puts "# XcodeYamlizer"
      new_ignored.each do |line|
        f.puts line
      end
      f.puts "# end"
    end
    
    puts "added to .gitignore:"
    puts new_ignored

  end
  


end

def chroot_to_repo
  root = File.expand_path("..",Rugged::Repository.discover(Dir.pwd))
  Dir.chdir(root)
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
    new_files = files.map do |file|
      convert_file file
    end
    puts "Finished!"
    return files, new_files
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

  def self.make_filepaths_non_relative files
    files.map do |file|
      file.sub(/^\.\//,"")
    end
  end

  def self.run_pre_commit
    chroot_to_repo()
    files_remove, files_add = convert_directory('./', false)
    files_remove = make_filepaths_non_relative files_remove
    files_add = make_filepaths_non_relative files_add
    repo_add_files files_add

    repo_remove_files files_remove
    repo_gitignore_add_files files_remove
  end

  def self.run_post_merge
    chroot_to_repo()
    convert_directory('./', true)
  end


end


