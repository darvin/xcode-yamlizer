require 'osx/plist'
require 'cobravsmongoose'
require 'json'
require 'yaml'
YAML::ENGINE.yamler='syck'

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


