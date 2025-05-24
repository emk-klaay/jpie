# frozen_string_literal: true

module GeneratorHelper
  def prepare_destination
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(File.join(destination, 'app/resources'))
  end

  def destination_file_exists?(file)
    File.exist?(File.join(destination, file))
  end

  def destination_file_content(file)
    File.read(File.join(destination, file))
  end

  def run_generator(args)
    # Parse the arguments to separate options from regular arguments
    parsed_args = []
    options = {}

    i = 0
    while i < args.length
      arg = args[i]

      if arg.start_with?('--')
        if arg.include?('=')
          key, value = arg[2..].split('=', 2)
          key = key.tr('-', '_').to_sym
          # Handle array options
          options[key] = if %i[relationships meta_attributes].include?(key)
                           value.split(',')
                         else
                           value
                         end
        else
          key = arg[2..].tr('-', '_').to_sym
          # Check if next argument is a value (doesn't start with --)
          if i + 1 < args.length && !args[i + 1].start_with?('--')
            i += 1
            value = args[i]
            # Handle array options
            options[key] = if %i[relationships meta_attributes].include?(key)
                             value.split(',')
                           else
                             value
                           end
          else
            options[key] = true
          end
        end
      else
        parsed_args << arg
      end

      i += 1
    end

    generator = generator_class.new(parsed_args, options, destination: destination)
    generator.destination_root = destination
    generator.invoke_all
  end

  def generator_class
    described_class
  end
end
