# frozen_string_literal: true

module ActiveRecord
  class FixtureSet
    class TableRow # :nodoc:
      def initialize(fixture, model_class:, tables:, timestamp:)
        @fixture = fixture
        @row     = fixture.to_h
        @model_class = model_class
        @tables = tables
        @timestamp = timestamp
        fill_row_model_attributes
      end

      def to_h
        @row
      end

      private
        def fill_row_model_attributes
          fill_timestamps
          interpolate_label
          generate_primary_key
          resolve_enums
          resolve_sti_reflections
        end

        def reflection_class
          @reflection_class ||= @row[@model_class.inheritance_column].try(:safe_constantize) || @model_class
        end

        def fill_timestamps
          if @model_class.record_timestamps
            @model_class.all_timestamp_attributes_in_model.each { |timestamp| @row[timestamp] ||= @timestamp }
          end
        end

        def interpolate_label
          @row.transform_values! do |value|
            value.respond_to?(:gsub) ? value.gsub("$LABEL", @fixture.label.to_s) : value
          end
        end

        def generate_primary_key
          if @model_class.column_names.include?(@model_class.primary_key)
            @row[@model_class.primary_key] ||= value_from_identification(@fixture.label, @model_class, @model_class.primary_key)
          end
        end

        def resolve_enums
          @model_class.defined_enums.each do |name, values|
            if @row.include?(name)
              @row[name] = values.fetch(@row[name], @row[name])
            end
          end
        end

        def resolve_sti_reflections
          reflection_class._reflections.each_value do |association|
            case association.macro
            when :belongs_to
              # Do not replace association name with association foreign key if they are named the same
              if association.name.to_s != association.join_foreign_key && value = @row.delete(association.name.to_s)
                value, type = value.scan(/\b\w+/)
                @row[association.join_foreign_key]  = value_from_identification(value, reflection_class, association.join_foreign_key)
                @row[association.join_foreign_type] = type if association.polymorphic? && type
              end
            when :has_many
              if association.options[:through] && value = @row.delete(association.name.to_s)
                add_join_records_sidestepping_fixtures_file(association, value)
              end
            end
          end
        end

        def add_join_records_sidestepping_fixtures_file(association, targets)
          targets = targets.is_a?(Array) ? targets : targets.split(/\s*,\s*/)

          @tables[association.through_reflection.table_name].concat \
            targets.map { |target| { association.through_reflection.foreign_key => @row[@model_class.primary_key],
                association.foreign_key => value_from_identification(target, association.klass, association.klass.primary_key) } }
        end

        def value_from_identification(value, klass, key)
          ActiveRecord::FixtureSet.identify(value, klass.type_for_attribute(key).type)
        end
    end
  end
end
