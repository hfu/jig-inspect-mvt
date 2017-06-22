require 'protobuf/message/message'
require 'protobuf/message/enum'
require 'protobuf/message/service'
require 'protobuf/message/extend'
require 'find'

module VectorTile
  ::Protobuf::OPTIONS[:"optimize_for"] = :LITE_RUNTIME
  class Tile < ::Protobuf::Message
    defined_in __FILE__
    class GeomType < ::Protobuf::Enum
      defined_in __FILE__
      UNKNOWN = value(:UNKNOWN, 0)
      POINT = value(:POINT, 1)
      LINESTRING = value(:LINESTRING, 2)
      POLYGON = value(:POLYGON, 3)
    end
    class Value < ::Protobuf::Message
      defined_in __FILE__
      optional :string, :string_value, 1
      optional :float, :float_value, 2
      optional :double, :double_value, 3
      optional :int64, :int_value, 4
      optional :uint64, :uint_value, 5
      optional :sint64, :sint_value, 6
      optional :bool, :bool_value, 7
      extensions 8..::Protobuf::Extend::MAX
    end
    class Feature < ::Protobuf::Message
      defined_in __FILE__
      optional :uint64, :id, 1, :default => 0
      repeated :uint32, :tags, 2, :packed => true
      optional :GeomType, :type, 3, :default => :UNKNOWN
      repeated :uint32, :geometry, 4, :packed => true
    end
    class Layer < ::Protobuf::Message
      defined_in __FILE__
      required :uint32, :version, 15, :default => 1
      required :string, :name, 1
      repeated :Feature, :features, 2
      repeated :string, :keys, 3
      repeated :Value, :values, 4
      optional :uint32, :extent, 5, :default => 4096
      extensions 16..::Protobuf::Extend::MAX
    end
    repeated :Layer, :layers, 3
    extensions 16..8191
  end
end

def print_result(result)
  result.keys.sort.each{|z|
    print "## zoom level #{z}\n"
    result[z].keys.sort{|a, b|
      result[z][b].values.inject(:+) <=> result[z][a].values.inject(:+)
    }.each{|l|
      print "- #{l}: #{result[z][l].keys.map{|k| result[z][l][k] == 0 ? nil : result[z][l][k].to_s + ' ' + k.to_s.downcase + (result[z][l][k] == 1 ? '' : 's')}.compact.join(', ')}\n"
    }
  }
end

count = 0
result = Hash.new{|h, k| h[k] = Hash.new{|h, k|
  h[k] = {:POINT => 0, :LINESTRING => 0, :POLYGON => 0}
}}
Find.find('vector') {|path| ## <== please rewrite here
  next unless /vector\/(\d*)\/(\d*)\/(\d*).mvt/.match(path)
  (z, x, y) = [$1, $2, $3].map{|v| v.to_i}
  tile = nil
  begin
    tile = VectorTile::Tile.new.parse_from(open(path)).to_hash
  rescue
    print "while reading #{path}: #{$!}\n"
    next
  end
  next if tile[:layers].nil?
  count += 1
  #print "#{path}: #{tile[:layers].nil? ? 0 : tile[:layers].size} layers (#{tile[:layers].map{|v| v[:name] +  '(' + (v[:features].nil? ? '0' :  v[:features].size.to_s) + ')'}.join(', ')}).\n"
  tile[:layers].each {|layer|
    next if layer[:features].nil?
    layer[:features].each {|f|
      result[z][layer[:name]][f[:type]] += 1
    }
    #result[z][layer[:name]] += layer[:features].size
  }
  print_result(result) if count % 100 == 0
}
print_result(result)
