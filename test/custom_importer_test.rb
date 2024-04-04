# frozen_string_literal: true

require_relative 'test_helper'

module SassC
  class CustomImporterTest < Minitest::Test
    include TempFileTest

    class CustomImporter < Importer
      def imports(path, _parent_path)
        if path.include?('styles')
          [
            Import.new("#{path}1.scss", source: '$var1: #000;'),
            Import.new("#{path}2.scss")
          ]
        else
          Import.new(path)
        end
      end
    end

    class NoFilesImporter < Importer
      def imports(_path, _parent_path)
        []
      end
    end

    class OptionsImporter < Importer
      def imports(_path, _parent_path)
        Import.new('name.scss', source: options[:custom_option_source])
      end
    end

    class ParentImporter < Importer
      def imports(_path, parent_path)
        Import.new('name.scss', source: ".#{File.basename(parent_path)} { color: red; }")
      end
    end

    def test_custom_importer_works
      temp_file('styles2.scss', '.hi { color: $var1; }')
      temp_file('fonts.scss', '.font { color: $var1; }')
      temp_file('スタイル.scss', '.test { color: $var1; }')

      data = <<~SCSS
        @import "styles";
        @import "fonts";
        @import "スタイル";
      SCSS

      engine = Engine.new(data, {
                            importer: CustomImporter
                          })

      assert_equal <<~CSS, engine.render
        .hi {
          color: #000;
        }

        .font {
          color: #000;
        }

        .test {
          color: #000;
        }
      CSS
    end

    def test_custom_importer_works_for_file_in_parent_dir
      temp_dir('sub')
      temp_file('a.scss', 'a {b: c}')
      temp_file('sub/b.scss', '@import "../a"')

      data = <<~SCSS
        @import "sub/b.scss";
      SCSS

      engine = Engine.new(data, {
                            importer: CustomImporter
                          })

      assert_equal <<~CSS, engine.render
        a {
          b: c;
        }
      CSS
    end

    def test_dependency_list
      base = Dir.pwd

      temp_dir('fonts')
      temp_dir('fonts/sub')
      temp_file('fonts/sub/sub_fonts.scss', '$font: arial;')
      temp_file('styles2.scss', '.hi { color: $var1; }')
      temp_file 'fonts/fonts.scss', <<~SCSS
        @import "sub/sub_fonts";
        .font { font-familiy: $font; color: $var1; }
      SCSS

      data = <<~SCSS
        @import "styles";
        @import "fonts";
      SCSS

      engine = Engine.new(data, {
                            importer: CustomImporter,
                            load_paths: ['fonts']
                          })
      engine.render

      dependencies = engine.dependencies.map(&:filename).map { |f| f.gsub(base, '') }

      assert_equal [
        '/styles1.scss',
        '/styles2.scss',
        '/fonts/fonts.scss',
        '/fonts/sub/sub_fonts.scss'
      ], dependencies
    end

    def test_custom_importer_works_with_no_files
      engine = Engine.new("@import 'fake.scss';", {
                            importer: NoFilesImporter
                          })

      assert_equal '', engine.render
    end

    def test_custom_importer_can_access_sassc_options
      engine = Engine.new("@import 'fake.scss';", {
                            importer: OptionsImporter,
                            custom_option_source: '.test { width: 30px; }'
                          })

      assert_equal <<~CSS, engine.render
        .test {
          width: 30px;
        }
      CSS
    end

    def test_parent_path_is_accessible
      engine = Engine.new("@import 'parent.scss';", {
                            importer: ParentImporter,
                            filename: 'import-parent-filename.scss'
                          })

      assert_equal <<~CSS, engine.render
        .import-parent-filename.scss {
          color: red;
        }
      CSS
    end
  end
end
