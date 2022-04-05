#!/usr/bin/ruby
# Jankun_Norme_v1.4.3
# Jankun Norminette
# Based on normez, edited by LÃ©o Sarochar 2020.

require 'optparse'
require 'tmpdir'

$major = 0
$minor = 0
$info = 0

$func_pattern = /^.*?(unsigned|signed)?\s*(sf\w+|_s|_t|void|int|char|short|long|float|double|bool|size_t)\s+((\w|\*)+)\s*\([^)]*(,\n|\)[^;]\s*)/
$func_prototype_pattern = /^.*?(unsigned|signed)?\s*(sf\w+|_s|_t|void|int|char|short|long|float|double|bool|size_t)\s+((\w|\*)+)\s*\([^)]*\);\s*/

class String
  def each_char
    split('').each { |i| yield i }
  end

  def add_style(color_code)
    if $options.include? :colorless
      "#{self}"
    else
      "\e[#{color_code}m#{self}\e[0m"
    end
  end

  def black
    add_style(31)
  end

  def red
    add_style(31)
  end

  def green
    add_style(32)
  end

  def yellow
    add_style(33)
  end

  def blue
    add_style(34)
  end

  def magenta
    add_style(35)
  end

  def cyan
    add_style(36)
  end

  def grey
    add_style(37)
  end

  def bold
    add_style(1)
  end

  def italic
    add_style(3)
  end

  def underline
    add_style(4)
  end
end

module FileType
  UNKNOWN = 0
  DIRECTORY = 1
  MAKEFILE = 2
  HEADER = 3
  SOURCE = 4
end

class FileManager
  attr_accessor :path
  attr_accessor :type

  def initialize(path, type)
    @path = path
    @type = type
    @type = get_file_type if @type == FileType::UNKNOWN
  end

  def get_file_type
    @type = if @path =~ /Makefile$/
              FileType::MAKEFILE
            elsif @path =~ /[.]h$/
              FileType::HEADER
            elsif @path =~ /[.]c$/
              FileType::SOURCE
            else
              FileType::UNKNOWN
            end
  end

  def get_content
    file = File.open(@path)
    content = file.read
    file.close
    content
  end
end

class FilesRetriever
  @@ignore = []

  def initialize
    @files = Dir['**/*'].select { |f| File.file? f }
    if File.file?('.gitignore')
      line_num = 0
      gitignore = FileManager.new('.gitignore', FileType::UNKNOWN).get_content
      gitignore.gsub!(/\r\n?/, "\n")
      gitignore.each_line do |line|
        if !line.start_with?('#') && line !~ /^\s*$/
          @@ignore.push(line.chomp)
        end
      end
    end

    @@ignore.push("tests/*") #ignoring tests files
    @@ignore.push("students")
    @nb_files = @files.size
    @idx_files = 0

    @dirs = Dir['**/*'].select { |d| File.directory? d }
    @nb_dirs = @dirs.size
    @idx_dirs = 0
  end

  def is_ignored_file(file)
    @@ignore.each do |ignored_file|
      if (ignored_file.include? "*")
        if file.include?(ignored_file) || file.include?(ignored_file.tr('*', ''))
          return true
        end
      elsif file == ignored_file
          return true
      end
    end
    false
  end

  def get_next_file
    if @idx_files < @nb_files
      file = FileManager.new(@files[@idx_files], FileType::UNKNOWN)
      @idx_files += 1
      file = get_next_file if !@@ignore.nil? && is_ignored_file(file.path)
      return file
    elsif @idx_dirs < @nb_dirs
      file = FileManager.new(@dirs[@idx_dirs], FileType::DIRECTORY)
      @idx_dirs += 1
      file = get_next_file if !@@ignore.nil? && is_ignored_file(file.path)
      return file
    end
    nil
  end
end

class CodingStyleChecker
  def initialize(file_manager)
    @file_path = file_manager.path
    @type = file_manager.type
    @file = nil
    if (@type != FileType::UNKNOWN) && (@type != FileType::DIRECTORY)
      @file = file_manager.get_content
    end
    check_file
  end

  def check_file
    if @type == FileType::UNKNOWN
      unless $options.include? :ignorefiles
        msg_brackets = '[' + @file_path + ']'
        msg_error = ' O1 - Your delivery folder should contain only files required for compilation.'
        $major += 1
        puts(msg_brackets.bold.red + msg_error.bold)
      end
      return
    end
    if @type == FileType::DIRECTORY
      check_dirname
      return
    end
    check_trailing_spaces_tabs
    check_indentation
    if @type != FileType::MAKEFILE
      check_filename
      check_too_many_columns
      check_too_broad_filename
      check_header
      check_several_assignments
      check_forbidden_keyword_func
      check_nested_conditional_branching
      check_too_many_else_if
      check_empty_parenthesis
      check_too_many_parameters
      check_curly_brackets
      check_space_after_keywords
      check_double_spaces
      check_misplaced_pointer_symbol
      check_comma_missing_space
      check_misplaced_comments
      check_operators_spaces
      check_condition_assignment
      check_l_o_lowercase
      check_global_const
      check_space_between_func_parantheses
      check_line_break_at_the_end
      check_typedef
      #check_ternary_flow
      if @type == FileType::SOURCE
        check_bad_header_separation
        check_functions_per_file
        check_function_lines
        check_empty_line_between_functions
      end
      #check_macro_used_as_constant if @type == FileType::HEADER
    elsif @type == FileType::HEADER
      check_indentation_of_preprocessor_directives
    elsif @type == FileType::MAKEFILE
      check_header_makefile
    end
  end

  def check_dirname
    filename = File.basename(@file_path)
    if filename !~ /^[a-z0-9]+([a-z0-9_]+[a-z0-9]+)*$/
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' O4 - Directory names should respect the snake_case naming convention'
      $major += 1
      puts(msg_brackets.bold.red + msg_error.bold)
    end
  end

  def check_filename
    filename = File.basename(@file_path)
    if filename !~ /^[a-z0-9]+([a-z0-9_]+[a-z0-9]+)*[.][ch]$/
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' O4 - Filenames should respect the snake_case naming convention'
      $major += 1
      puts(msg_brackets.bold.red + msg_error.bold)
    end
  end

  def check_too_many_columns
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      length = 0
      line.each_char do |char|
        length += if char == "\t"
                    8
                  else
                    1
                  end
      end
      if length - 1 > 80
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' F3 - Too long line (' + (length - 1).to_s + ' > 80)'
        $major += 1
        puts(msg_brackets.bold.red + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_too_broad_filename
    if @file_path =~ /(.*\/|^)(string.c|str.c|my_string.c|my_str.c|algorithm.c|my_algorithm.c|algo.c|my_algo.c|program.c|my_program.c|prog.c|my_prog.c|program.c)$/
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' O4 - Too broad filename. You should rename this file'
      $major += 1
      puts(msg_brackets.bold.red + msg_error.bold)
    end
  end

  def check_header
    line_nb = 1
    header_first_line = 1
    @file.each_line do |line|
      if line_nb == 1 && line !~ /\/\*/
        header_first_line = 0
      end
      line_nb += 1
    end
    if header_first_line == 0 || @file !~ /\/\*\n\*\* EPITECH PROJECT, [0-9]{4}\n\*\* .*\n\*\* File description:\n(\*\* .*\n)+\*\/\n.*/
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' G1 - You must start your source code with a correctly formatted Epitech standard header'
      $major += 1
      puts(msg_brackets.bold.red + msg_error.bold)
    end
  end

  def check_typedef
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /typedef/
        words = line.scan(/(\w+)/)
        if line !~ /(_t;)$/
          msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
          msg_error = ' V1 - The type names defined with typedef doesn\'t have "_t" in the end'
          puts(msg_brackets.bold.red + msg_error.bold)
          $major += 1
        elsif words[2][0] =~ /[^a-z_0-9]/ or words[3][0] =~ /[^a-z_0-9]/
            msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
            msg_error = ' V1 - The type names must be composed exclusively of lowercase, numbers, and underscores'
            puts(msg_brackets.bold.red + msg_error.bold)
            $major += 1
        end
      end
      line_nb += 1
    end
  end

  def check_function_lines
    scope_lvl = 0
    count = -2
    sec_count = 5
    line_nb = 1
    function_start = -1
    many_lines = []
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ $func_pattern
        function_start = line_nb
        count = 0
      else
        if function_start != -1
          scope_lvl += line.count '{'
          scope_lvl -= line.count '}'
          if (scope_lvl > 0)
            if (count > 21 && sec_count > 4)
              many_lines.push(line_nb);
              sec_count = 0
            end
          else
            many_lines.each do |line_index|
              msg_brackets = '[' + @file_path + ':' + line_index.to_s + ']'
              msg_error = ' F4 - Too long function'
              $major += 1
              puts(msg_brackets.bold.red + msg_error.bold)
            end
            function_start = -1
            many_lines = []
            count = 0
          end
          sec_count += 1
          count += 1
        end
      end
      line_nb += 1
    end
  end

  def check_several_assignments
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /^[ \t]*for ?\(/
        line_nb += 1
        next
      end
      assignments = 0
      line.each_char do |char|
        assignments += 1 if char == ';'
      end
      if assignments > 1
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' L1 - Several assignments on the same line'
        $major += 1
        puts(msg_brackets.bold.red + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_forbidden_keyword_func
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      line.scan(/(^|[^0-9a-zA-Z_])(printf|dprintf|fprintf|vprintf|sprintf|snprintf|vprintf|vfprintf|vsprintf|vsnprintf|asprintf|scranf|memcpy|memset|memmove|strcat|strchar|strcpy|atoi|strlen|strncat|strncpy|strcasestr|strncasestr|strcmp|strncmp|strtok|strnlen|strdup|realloc)[^0-9a-zA-Z]/) do
        unless $options.include? :ignorefunctions
          msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
          msg_error = " Are you sure that this function is allowed: '".bold
          msg_error += Regexp.last_match(2).bold.red
          msg_error += "'?".bold
          puts(msg_brackets.bold.red + msg_error)
        end
      end
      line.scan(/(^|[^0-9a-zA-Z_])(goto)[^0-9a-zA-Z]/) do
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " C3 - Your code should not contain the goto keyword."
        $minor += 1
        puts(msg_brackets.bold.red + msg_error)
      end
      line_nb += 1
    end
  end

  def check_too_many_else_if
    line_nb = condition_start = 1
    count = 0
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      line[0] = '' while [' ', "\t"].include?(line[0])
      if line =~ /^if ?\(/
        condition_start = line_nb
        count = 1
      elsif line =~ /else if ?/
        count += 1
        if count > 2
          msg_brackets = '[' + @file_path + ':' + condition_start.to_s + ']'
          msg_error = ' C1 - Nested conditonal branchings with a depth of 3 or more should be avoided and an if block should not contain more than 3 branchings'
          $minor += 1
          puts(msg_brackets.bold.green + msg_error.bold)
        end
      end
      line_nb += 1
    end
  end

  def check_nested_conditional_branching
    line_nb = 1
    in_switch = 0
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /switch\s*(.*)\s*\{/
        in_switch = line.length - line.lstrip.length
      end
      if in_switch != 0 && in_switch == (line.length - line.lstrip.length) && line =~ /\}/
        in_switch = 0
      end
      if in_switch == 0 && line =~ /^( {16})|(\t{4})/
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' C1 - Nested conditonal branchings with a depth of 3 or more should be avoided and an if block should not contain more than 3 branchings'
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_indentation_of_preprocessor_directives
    line_nb = 1
    indentation_level = 0
    @file.each_line do |line|
      if line.length == 1 || line =~ /^\s*\/\// || line =~ /^\/\*/ || line =~ /\*\*/ || line =~ /\*\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /^#\s*if/
        indentation_level += 1
      elsif line =~ /^#\s*endif/
        indentation_level -= 1
      else
        if line =~ /^#/ && indentation_level > 0
          msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
          msg_error = ' G3 - Preprocessor directives should be indented'
          $minor += 1
          puts(msg_brackets.bold.green + msg_error.bold)
        elsif line =~ /^\s+\w+/
          msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
          msg_error = ' G3 - Preprocessor directives should be indented'
          $minor += 1
          puts(msg_brackets.bold.green + msg_error.bold)
        end
      end
      line_nb += 1
    end
  end

  def check_return_without_parentheses
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /return(\(|\s+|.*+;)/ && line !~ /return\s*\(.*\)/
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " L3 - Return without parentheses."
        $info += 1
        puts(msg_brackets.bold.grey + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_trailing_spaces_tabs
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ / $/
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' G8 - Trailing space(s) at the end of the line'
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      elsif line =~ /\t$/
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' G8 - Trailing tabulation(s) at the end of the line'
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_indentation
    line_nb = 1
    if @type == FileType::MAKEFILE
      valid_indent = '\t'
      bad_indent_regexp = /^ +.*$/
      bad_indent_name = 'space'
    else
      valid_indent = ' '
      bad_indent_regexp = /^\t+.*$/
      bad_indent_name = 'tabulation'
    end
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      indent = 0
      while line[indent] == valid_indent
        indent += 1
      end
      if line =~ bad_indent_regexp
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " L2 - Wrong indentation: #{bad_indent_name}s are not allowed."
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      elsif indent % 4 != 0
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' L2 - Wrong indentation'
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_functions_per_file
    functions = 0
    tab = @file.split(/\n/).map { |line| line + "\n" }
    for i in 0..tab.length-1
      line = tab[i]
      if line =~ /^\s*\/\// #Skip commented lines
        next;
      end
      if line =~ $func_pattern && tab[i+1] !~ /\w+\);/
        functions += 1
      end
    end
    if functions > 5
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' O3 - More than 5 functions in the same file (' + functions.to_s + ' > 5)'
      $major += 1
      puts(msg_brackets.bold.red + msg_error.bold)
    end
  end

  def check_ternary_flow
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /[^'"]\s\?.*(:.*\w\(.*\))|(\w\(.*\).*:.*)/
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' C2 - Ternaries should not be used to control program flow'
        $info += 1
        puts(msg_brackets.bold.grey + msg_error.bold)
      end
      line_nb += 1;
    end
  end

  def check_bad_header_separation
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /^static\s*inline/ || line =~ /^#define/ #|| line =~ $func_prototype_pattern
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' H1 - Bad separation between source file and header file'
        $major += 1
        puts(msg_brackets.bold.red + msg_error.bold)
      end
      line_nb += 1;
    end
  end

  def check_empty_parenthesis
    line_nb = 1
    missing_bracket = false
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /^.*?(unsigned|signed)?\s*(void|int|char|short|long|float|double)\s+(\w+)\s*\(\)\s*[^;]/
          msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
          msg_error = " F5 - This function takes no parameter, it should take 'void' as argument."
          $major += 1
          puts(msg_brackets.bold.red + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_too_many_parameters
    @file.scan(/\(([^(),]*,){4,}[^()]*\)[ \t\n]+{/).each do |_match|
      if _match =~ /^\s*\/\// #Skip commented lines
        next;
      end
      msg_brackets = '[' + @file_path + ']'
      msg_error = " F5 - A function should not need more than 4 arguments."
      $major += 1
      puts(msg_brackets.bold.red + msg_error.bold)
    end
  end

  def check_curly_brackets
    line_nb = 1
    statement_detected = false
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /^.*?\s*(unsigned|signed)?\s*(void|int|char|short|long|float|double)\s+((\w|\*)+)\s*\([^)]*\)[^\S\r\n]*{/
        msg_brackets = '[' + @file_path +  ':' + line_nb.to_s + ']'
        msg_error = " L4 - Curly brackets misplaced on a function."
        $minor += 1
        puts(msg_brackets.bold.red + msg_error.bold)
      else
        line[0] = '' while [' ', "\t"].include?(line[0])
        if (statement_detected == true)
          if line =~ /^{/
            msg_brackets = '[' + @file_path +  ':' + (line_nb - 1).to_s + ']'
            msg_error = " L4 - Curly brackets misplaced."
            $minor += 1
            puts(msg_brackets.bold.red + msg_error.bold)
          end
        end
        if line =~ /(}|[^\S\r\n]*)(if|for|while|switch|else)\s*\(.*\)([ ]*|\))[^0-9a-zA-Z_]/
          statement_detected = true
        else
          statement_detected = false
        end
      end
      line_nb += 1
    end
  end

  def check_space_between_func_parantheses
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      line.scan(/^.*?(unsigned|signed)?\s*(void|int|char|short|long|float|double)\s+(\w+)\s+\([^)]*\)[^;]\s*/) do |match|
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " L3 - Trailing space beetween function and parantheses."
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_space_after_keywords
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      line.scan(/(return|if|else if|else|while|for)\(/) do |match|
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " L3 - Missing space after keyword '" + match[0] + "'."
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_double_spaces
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /\w+  .+/
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " L3 - Misplaced space(s)"
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_misplaced_pointer_symbol
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      line.scan(/([^(\t ]+_t|int|signed|unsigned|char|long|short|float|double|void|const|struct [^ ]+)\*/) do |match|
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " V3 - Misplaced pointer symbol after '" + match[0] + "'."
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_global_const
    line_nb = 1
    scope_lvl = 0;
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      scope_lvl += line.count '{'
      scope_lvl -= line.count '}'
      if scope_lvl == 0 && line =~ /([0-9a-zA-Z]+)\s*=\s*([0-9a-zA-Z_]+)/
        if !(line =~ /(const)/)
          msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
          msg_error = " G4 - Global variable must be const."
          $minor += 1
          puts(msg_brackets.bold.green + msg_error.bold)
        end
      end
      line_nb += 1
    end
  end

  def check_macro_used_as_constant
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /#define [^ ]+ [0-9]+([.][0-9]+)?/
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' H3 - Macros should not be used for constants'
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_header_makefile
    if @file !~ /##\n## EPITECH PROJECT, [0-9]{4}\n## .*\n## File description:\n## .*\n##\n.*/
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' G1 - You must start your source code with a correctly formatted Epitech standard header.'
      $major += 1
      puts(msg_brackets.bold.red + msg_error.bold)
    end
  end

  def check_misplaced_comments
    level = 0
    line_nb = 1
    @file.each_line do |line|
      level += line.count '{'
      level -= line.count '}'
      if (level != 0) && (line =~ /\/\*/ || line =~ /\/\//)
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' F6 - Comment inside a function'
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_comma_missing_space
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      quoted = false
      line.chars.each_with_index{|i, index|
        if i.include? "\"" or i.include? "\'"
           quoted = !quoted
        end
        if !quoted and i == ',' and line[index + 1] != ' ' and !line[index + 1].include?("\n")
            msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
            msg_error = ' L3 - Missing space after comma'
            $minor += 1
            puts(msg_brackets.bold.green + msg_error.bold)
        end
     }
      line_nb += 1
    end
  end

  def put_error_sign(sign, line_nb)
    msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
    msg_error = " L3 - Misplaced space(s) around '" + sign + "' sign."
    $minor += 1
    puts(msg_brackets.bold.green + msg_error.bold)
  end

  def check_operators_spaces
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      # A space on both ends
      line.scan(/([^\t&|=^><+\-*%\/! ]=[^=]|[^&|=^><+\-*%\/!]=[^= \n])/) do
        put_error_sign('=', line_nb)
      end
      line.scan(/([^\t ]==|==[^ \n])/) do
        put_error_sign('==', line_nb)
      end
      line.scan(/([^\t ]!=|!=[^ \n])/) do
        put_error_sign('!=', line_nb)
      end
      line.scan(/([^\t <]<=|[^<]<=[^ \n])/) do
        put_error_sign('<=', line_nb)
      end
      line.scan(/([^\t >]>=|[^>]>=[^ \n])/) do
        put_error_sign('>=', line_nb)
      end
      line.scan(/([^\t ]&&|&&[^ \n])/) do
        put_error_sign('&&', line_nb)
      end
      line.scan(/([^\t ]\|\||\|\|[^ \n])/) do
        put_error_sign('||', line_nb)
      end
      line.scan(/([^\t ]\+=|\+=[^ \n])/) do
        put_error_sign('+=', line_nb)
      end
      line.scan(/([^\t ]-=|-=[^ \n])/) do
        put_error_sign('-=', line_nb)
      end
      line.scan(/([^\t ]\*=|\*=[^ \n])/) do
        put_error_sign('*=', line_nb)
      end
      line.scan(/([^\t ]\/=|\/=[^ \n])/) do
        put_error_sign('/=', line_nb)
      end
      line.scan(/([^\t ]%=|%=[^ \n])/) do
        put_error_sign('%=', line_nb)
      end
      line.scan(/([^\t ]&=|&=[^ \n])/) do
        put_error_sign('&=', line_nb)
      end
      line.scan(/([^\t ]\^=|\^=[^ \n])/) do
        put_error_sign('^=', line_nb)
      end
      line.scan(/([^\t ]\|=|\|=[^ \n])/) do
        put_error_sign('|=', line_nb)
      end
      line.scan(/([^\t |]\|[^|]|[^|]\|[^ =|\n])/) do
        # Minifix for Matchstick
        line.scan(/([^'"]\|[^'"])/) do
          put_error_sign('|', line_nb)
        end
      end
      line.scan(/([^\t ]\^|\^[^ =\n])/) do
        line.scan(/([^'"]\^|\^[^'"])/) do
          put_error_sign('^', line_nb)
        end
      end
      line.scan(/([^\t ]>>[^=]|>>[^ =\n])/) do
        line.scan(/([^'"]>>[^=]|>>[^'"])/) do
          put_error_sign('>>', line_nb)
        end
      end
      line.scan(/([^\t ]<<[^=]|<<[^ =\n])/) do
        line.scan(/([^'"]<<[^=]|<<[^'"])/) do
          put_error_sign('<<', line_nb)
        end
      end
      line.scan(/([^\t ]>>=|>>=[^ \n])/) do
        put_error_sign('>>=', line_nb)
      end
      line.scan(/([^\t ]<<=|<<=[^ \n])/) do
        put_error_sign('<<=', line_nb)
      end
      # No space after
      line.scan(/([^!]! )/) do
        put_error_sign('!', line_nb)
      end
      line.scan(/([^a-zA-Z0-9]sizeof )/) do
        put_error_sign('sizeof', line_nb)
      end
      line.scan(/([^a-zA-Z)\]]\+\+[^(\[*a-zA-Z])/) do
        put_error_sign('++', line_nb)
      end
      line.scan(/([^a-zA-Z)\]]--[^\[(*a-zA-Z])/) do
        line.scan(/([^'"]--[^'"])/) do
          put_error_sign('--', line_nb)
        end
      end
      line.scan(/ ;$/) do
        put_error_sign(';', line_nb)
      end
      line_nb += 1
    end
  end

  def check_condition_assignment
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      line.scan(/(if.*[^&|=^><+\-*%\/!]=[^=].*==.*)|(if.*==.*[^&|=^><+\-*%\/!]=[^=].*)/) do
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = ' L1 - Condition and assignment on the same line'
        $minor += 1
        puts(msg_brackets.bold.green + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_empty_line_between_functions
    @file.scan(/\n{3,}^[^ \n\t]+ [^ \n\t]+\([^\n\t]*\)[^;]/).each do |_match|
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' G2 - Too many empty lines between functions'
      $minor += 1
      puts(msg_brackets.bold.green + msg_error.bold)
    end
    @file.scan(/[^\n]\n^[^ \n\t]+ [^ \n\t]+\([^\n\t]*\)[^;]/).each do |_match|
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' G2 - Missing empty line between one functions'
      $minor += 1
      puts(msg_brackets.bold.green + msg_error.bold)
    end
  end

  def check_l_o_lowercase
    line_nb = 1
    @file.each_line do |line|
      if line =~ /^\s*\/\// #Skip commented lines
        line_nb += 1;
        next;
      end
      if line =~ /\s+(l|O)\s+/ && !(line =~ /^((\*\*)|(\/\/))/)
        msg_brackets = '[' + @file_path + ':' + line_nb.to_s + ']'
        msg_error = " V1 - identifier should not be composed of only 'l' (L lowercase) or 'O' (o uppercase)."
        $info += 1
        puts(msg_brackets.bold.grey + msg_error.bold)
      end
      line_nb += 1
    end
  end

  def check_line_break_at_the_end
    if @file[-1] != "\n"
      msg_brackets = '[' + @file_path + ']'
      msg_error = ' A3 - File should end with a line break'
      $info += 1
      puts(msg_brackets.bold.grey + msg_error.bold)
    end
  end
end

class UpdateManager
  def initialize(script_path)
    path = File.dirname(script_path)
    tmp_dir = Dir.tmpdir
    @script_path = script_path
    @remote_path = "#{tmp_dir}/__jankun_norme_remote"
    @backup_path = "#{tmp_dir}/__jankun_norme_backup"
    @remote = system("curl -s https://raw.githubusercontent.com/LeoSarochar/jankun_norme/main/jankun_norme.rb > #{@remote_path}")
  end

  def clean_update_files
    system("rm -rf #{@backup_path}")
    system("rm -rf #{@remote_path}")
  end

  def can_update
    unless @remote
      clean_update_files
      return false
    end
    @current = `cat #{@script_path} | grep 'Jankun_Norme_v' | cut -c 17- | head -1 | tr -d '.'`
    @latest = `cat #{@remote_path} | grep 'Jankun_Norme_v' | cut -c 17- | head -1 | tr -d '.'`
    @latest_disp = `cat #{@remote_path} | grep 'Jankun_Norme_v' | cut -c 17- | head -1`
    return true if @current.to_i < @latest.to_i

    clean_update_files
    false
  end

  def update
    return unless @current < @latest

    update_msg = `cat #{@remote_path} | grep 'Changelog: ' | cut -c 14- | head -1 | tr -d '.'`
    print("A new version is available : Jankun Norme v#{@latest_disp}".bold.yellow)
    # print(' => Changelog : '.bold)
    # print(update_msg.to_s.bold.blue)
    response = nil
    Kernel.loop do
      print('Update Jankun Norme ? [Y/n]: ')
      response = gets.chomp
      break if ['N', 'n', 'no', 'Y', 'y', 'yes', ''].include?(response)
    end
    if %w[N n no].include?(response)
      puts('Update skipped. You can also use the --no-update (or -u) option to prevent auto-updating.'.bold.blue)
      clean_update_files
      return
    end
    puts('Downloading update...')
    system("cat #{@script_path} > #{@backup_path}")
    exit_code = system("cat #{@remote_path} > #{@script_path}")
    unless exit_code
      print('Error while updating! Cancelling...'.bold.red)
      system("cat #{@backup_path} > #{@script_path}")
      clean_update_files
      Kernel.exit(false)
    end
    clean_update_files
    puts('Jankun Norme has been successfully updated!'.bold.green)
    Kernel.exit(true)
  end
end

$options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: `ruby ' + $PROGRAM_NAME + ' [-ufmi]`'
  opts.on('-u', '--no-update', "Don't check for updates") do |o|
    $options[:noupdate] = o
  end
  opts.on('-f', '--ignore-files', 'Ignore forbidden files') do |o|
    $options[:ignorefiles] = o
  end
  opts.on('-m', '--ignore-functions', 'Ignore forbidden functions') do |o|
    $options[:ignorefunctions] = o
  end
  opts.on('-i', '--ignore-all', 'Ignore forbidden files & forbidden functions (same as `-fm`)') do |o|
    $options[:ignorefiles] = o
    $options[:ignorefunctions] = o
  end
  opts.on('-c', '--colorless', 'Disable output styling') do |o|
    $options[:colorless] = o
  end
end

begin
  opt_parser.parse!
rescue OptionParser::InvalidOption => e
  puts('Error: ' + e.to_s)
  puts(opt_parser.banner)
  Kernel.exit(false)
end

unless $options.include?(:noupdate)
  updater = UpdateManager.new($PROGRAM_NAME)
  updater.update if updater.can_update
end

files_retriever = FilesRetriever.new
while (next_file = files_retriever.get_next_file)
  CodingStyleChecker.new(next_file)
end
puts("")
puts("Major : %s" % $major)
puts("Minor : %s" % $minor)
puts("Info : %s" % $info)