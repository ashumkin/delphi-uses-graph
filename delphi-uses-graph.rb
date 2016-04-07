#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

Version = '0.0.1'

module Delphi

  module Uses

    module Graph

      class Options < OptionParser
        attr_reader :project
        def initialize(args)
          super()
          args = args.dup
          separator ''
          separator 'Options:'

          @project = nil

          init
          parse!(args)
          validate
        end

        def init
          on('-P', '--project FILE', 'Project filename') do |project|
            @project = project
          end

          on_tail('-h', '--help', 'Show this message')  do
            puts help
            exit
          end
        end

        def validate
          unless @project
            puts help
            exit
          end
        end

      end # class Options

      class PascalLine < ::String
        def initialize(str)
          super
          strip!
          # remove //... comments
          gsub!(/\/\/.+$/, '')
          # remove {...} comments
          gsub!(/{.*?}/, '')
          # remove (*...*) comments
          gsub!(/\(\*.*\*\)/, '')
        end
      end

      class PascalUnitDef < ::String
        attr_reader :path
        attr_accessor :absent
        def initialize(str)
          super
          strip!
          @path = self.dup
          gsub!(/^(\S+) in.+/, '\1')
          @path.gsub!(/^.+in\s+'([^']+)'/, '\1')
          # localize path
          @path.gsub!('\\', File::SEPARATOR)
        end

        def inspect
          '<%s: %s; @path=%s>' % [self.class.name, self, @path]
        end
      end

      class UnitDependecies < ::Array
        def initialize(owner)
          super()
          @owner = owner
        end

        def to_s
          r = self.dup
          r.delete_if do |unit|
            unit.absent
          end
          r = r.join(' ')
          r = "{#{r}}" unless r.empty?
          r
        end

        def <<(unit)
          super unless include?(unit)
        end
      end # class UnitDependecies

      class Unit
        attr_reader :index, :name, :dependencies, :path, :basename, :absent, :loaded
        def initialize(walker, path)
          @walker = walker
          # index to sort hash in order of addition
          @index = walker.count
          @path = path
          @basename = File.basename(@path)
          @name = @basename.gsub(/\.(pas|dpr)$/, '')
          @dependencies = UnitDependecies.new(self)
          @absent = nil
          @loaded = false
        end

        def inspect
          [name, @dependencies]
        end

        def to_s
          "#{name} -- #{@dependencies.to_s}"
        end

        def any_dependency_exist?
          dependencies.each do |dep|
            return true if @walker[dep] && !@walker[dep].absent
          end
          return false
        end

        def include_to_project?
          ! absent && ! dependencies.empty? && any_dependency_exist?
        end

        def scan_file(file)
          in_uses = false
          while line = file.gets do
            line = PascalLine.new(line)
            if line =~ /^uses\b/
              in_uses = true
              line.gsub!(/\buses\b/, '')
            end
            if in_uses
              if (units = (line + ' ').split(';')).size > 1
                # ; exists
                in_uses = false
                line = units.first
              end
              units = line.split(',')
              units.map do |unit|
                unit = PascalUnitDef.new(unit)
                yield unit unless unit.empty?
              end
            end
          end
        end

        def readfile
          @loaded = true
          File.open(@path, 'r', :encoding => 'Windows-1251') do |f|
            scan_file(f) do |unit|
              @dependencies << unit
            end
          end
          @absent = false
        rescue Errno::ENOENT
          # suppress "no file"
        rescue Exception
          raise
        end

      end # class Unit

      class UnitWalker < ::Hash
        def add_unit(unit)
          if already_walked?(unit)
            return
          end
          unit = do_add(unit)
          add_unit_dependencies(unit)
        end

        def already_walked?(unit)
          return include?(unit)
        end

        def do_add(unit)
          unit = Unit.new(self, unit)
          self[unit.name] = unit
          # add :main project to know starting point
          self[:main] = unit if size == 1
          return unit
        end

        def run(project)
          add_unit(project)
        end

        def find_unit(unit)
          project_file_dir = File.dirname(self[:main].path)
          unit_path = unit.path
          unit_path += '.pas' unless unit_path =~ /\.pas$/
          unit_path = File.join(project_file_dir, unit_path)
          unit.absent = ! File.exists?(unit_path)
          if unit.absent
            return nil
          else
            return unit_path
          end
        end

        def add_unit_dependencies(unit)
          unit.readfile
          unit.dependencies.each do |dep|
            next if already_walked?(dep)
            if path = find_unit(dep)
              do_add(path)
            end
          end
          update_all_dependencies
        end

        def update_all_dependencies
          dependencies.values.each do |unit|
            add_unit_dependencies(unit) unless unit.loaded || unit.absent
          end
        end

        def dot
          r = ['graph {']
          dependencies.sort_by do |k, v|
            v.index
          end.each do |dep|
            next if dep[0] == :main
            r << '    %s;' % dep[1].to_s if dep[1].include_to_project?
          end
          r << '}'
          return r.join("\n")
        end

        def dependencies
          self
        end
      end # class UnitWalker

    end # module Graph

  end # module Uses

end # module Delphi

if __FILE__ == $0
  opts = Delphi::Uses::Graph::Options.new(ARGV)
  walker = Delphi::Uses::Graph::UnitWalker.new
  walker.run(opts.project)
  print walker.dot
end
