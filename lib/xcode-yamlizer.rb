# encoding: UTF-8
require 'xcode-yamlizer/version'
require 'xcode-yamlizer/dumpers'
require 'rugged'
require 'pathname'

require 'find'

$KCODE = 'UTF8' unless RUBY_VERSION >= '1.9'
require 'pp'


YAML_FORMATS = [".yaml", ".yml"]
PLIST_FORMATS = [".pbxproj"]
XML_FORMATS = [".xib", ".storyboard", \
    /(.*).xcdatamodeld\/(.*).xcdatamodel\/contents$/, \
    /(.*).xccurrentversion$/
]


XCODE_FORMATS = PLIST_FORMATS + XML_FORMATS


DUMPERS = [
  [YAML_FORMATS, YamlDumper],
  [PLIST_FORMATS, PlistDumper],
  [XML_FORMATS, XmlDumper],
]


module Enumerable
  def include_filename?(filename)
    self.each do |elem|
      if elem.kind_of? Regexp and elem.match(filename)
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
  files.each do |file|
    `git add '#{file}'`
  end
end

def repo_remove_files(files)
  files.each do |file|
      `git rm --cached '#{file}'`
  end
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
    repo_add_files [".gitignore"]

  end
  


end

def chroot_to_repo
  root = File.expand_path("..",Rugged::Repository.discover(Dir.pwd))
  Dir.chdir(root)
end



module XcodeYamlizer
  def self.convert_directory(dir, to_xcode, verbose=false, ignore_paths=[])
    puts "Conventering directory '#{dir}'..." if verbose
    files = []
    formats = to_xcode ? YAML_FORMATS : XCODE_FORMATS

    Find.find(dir) do |path|
      if FileTest.directory?(path)
        if ignore_paths.include?(path) or ignore_paths.include? path.gsub(/^\.\//,"")
          puts "Ignored in submodule: #{path}" if verbose
          Find.prune
        else
          next
        end
      else
        files += [path] if formats.include_filename? path
      end
    end

    puts "Found:" if verbose
    puts files if verbose
    new_files = files.map do |file|
      convert_file file, verbose
    end
    puts "Finished!" if verbose
    return files, new_files
  end

  def self.convert_file(input, verbose=false)
    result = nil
    if YAML_FORMATS.include_filename? input
      output = input.chomp(File.extname(input))
      FileUtils.cp output, "#{output}~"
    elsif XCODE_FORMATS.include_filename? input
      output = "#{input}.yaml"

    end
    result = load(input)
    dump(output, result)
    if result
      puts "#{input} => #{output}" if verbose
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

  def self.find_submodules
    paths = `git submodule foreach --quiet 'echo $path'`
    paths.lines.map do |line|
      line.chomp
    end
  end

  def self.run_pre_commit
    chroot_to_repo()
    paths_to_ignore = find_submodules


    files_remove, files_add = convert_directory('./', \
                                false, \
                                true, \
                                paths_to_ignore)
    files_remove = make_filepaths_non_relative files_remove
    files_add = make_filepaths_non_relative files_add
    repo_add_files files_add

    repo_remove_files files_remove
    repo_gitignore_add_files files_remove
  end

  def self.run_post_merge
    chroot_to_repo()
    paths_to_ignore = find_submodules
    convert_directory('./', true, false, paths_to_ignore)
  end


end


