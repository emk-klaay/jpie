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
    parsed_args, options = parse_generator_arguments(args)
    create_and_run_generator(parsed_args, options)
  end

  private

  def parse_generator_arguments(args)
    parsed_args = []
    options = {}
    i = 0

    while i < args.length
      arg = args[i]
      if arg.start_with?('--')
        i = parse_option_argument(args, i, options)
      else
        parsed_args << arg
      end
      i += 1
    end

    [parsed_args, options]
  end

  def parse_option_argument(args, index, options)
    arg = args[index]

    if arg.include?('=')
      parse_option_with_equals(arg, options)
      index
    else
      parse_option_without_equals(args, index, options)
    end
  end

  def parse_option_with_equals(arg, options)
    key, value = arg[2..].split('=', 2)
    key = normalize_option_key(key)
    options[key] = process_option_value(key, value)
  end

  def parse_option_without_equals(args, index, options)
    key = normalize_option_key(args[index][2..])

    if next_arg_is_value?(args, index)
      index += 1
      value = args[index]
      options[key] = process_option_value(key, value)
    else
      options[key] = true
    end

    index
  end

  def normalize_option_key(key)
    key.tr('-', '_').to_sym
  end

  def process_option_value(key, value)
    if %i[relationships meta_attributes].include?(key)
      value.split(',')
    else
      value
    end
  end

  def next_arg_is_value?(args, index)
    index + 1 < args.length && !args[index + 1].start_with?('--')
  end

  def create_and_run_generator(parsed_args, options)
    generator = generator_class.new(parsed_args, options, destination: destination)
    generator.destination_root = destination
    generator.invoke_all
  end

  def generator_class
    described_class
  end
end
