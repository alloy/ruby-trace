module RubyTrace
  class FileNode
    attr_reader :path, :lines

    def initialize(path)
      @path = path
      @lines = {}
    end

    def line_for_lineno(lineno)
      lineno = lineno.to_i
      @lines[lineno] ||= Line.new(self, lineno)
    end
  end

  class Line
    attr_reader :file, :lineno, :calls, :method_definition

    def initialize(file, lineno)
      @file, @lineno = file, lineno
    end

    def add_call(call)
      @calls ||= []
      @calls << call
    end

    def method_definition_with_mod_and_name(mod, name)
      if @method_definition
        if @method_definition.line != self || @method_definition.mod != mod || @method_definition.name != name
          raise 'inconsistency!'
        end
      else
        @method_definition = Method.new(self, mod, name)
      end
      @method_definition
    end
  end

  class Method
    attr_reader :line, :mod, :name, :callers

    def initialize(line, mod, name)
      @line, @mod, @name = line, mod, name
      @callers = []
    end

    def add_caller(from_line, index, arguments)
      call = Call.new(self, from_line, index, arguments)
      @callers << call
      call
    end

    class Call
      attr_accessor :method, :from_line, :index, :arguments, :return_value
      def initialize(method, from_line, index, arguments)
        @method, @from_line, @index, @arguments = method, from_line, index, arguments
      end
    end
  end

  class Trace
    attr_reader :files

    def initialize
      @files = {}
      @call_index = 0
    end

    def file_for_path(path)
      path = File.expand_path(path)
      return if path == __FILE__
      @files[path] ||= FileNode.new(path)
    end

    def line_for_path_and_lineno(path, lineno)
      if file = file_for_path(path)
        file.line_for_lineno(lineno)
      end
    end

    def line_from_call_trace_point(tp)
      # The C API probably makes this way more robust and easy.
      backtrace = tp.binding.eval('caller')
      backtrace.reject! { |call| call.start_with?(__FILE__) }
      backtrace_line = backtrace[1]

      matches = backtrace_line.match(/^(.+):(\d+)/)
      line_for_path_and_lineno(matches[1], matches[2])
    end

    def arguments_from_call_trace_point(tp)
      # At call time only the method arguments will be defined.
      tp.binding.eval("local_variables").inject({}) do |vars, name|
        vars[name] = tp.binding.eval(name.to_s)
        vars
      end
    end

    def trace
      # TODO stack is not thread local and thus safe!
      stack = []
      trace = TracePoint.new(:call, :return) do |tp|
        next if tp.path == __FILE__
        case tp.event
        when :call
          if from_line = line_from_call_trace_point(tp)
            to_line = line_for_path_and_lineno(tp.path, tp.lineno)
            method = to_line.method_definition_with_mod_and_name(tp.defined_class, tp.method_id)
            call = method.add_caller(from_line, @call_index, arguments_from_call_trace_point(tp))
            from_line.add_call(call)
            @call_index += 1
            stack << call
          end
        when :return
          call = stack.pop
          if call.nil? || call.method.name != tp.method_id || call.method.mod != tp.defined_class
            raise 'inconsistency!'
          end
          call.return_value = tp.return_value
        end
      end
      trace.enable
      yield
      unless stack.empty?
        raise 'inconsistency!'
      end
    ensure
      trace.disable
    end

    def pretty_print
      @files.sort_by(&:first).each do |_, file|
        puts "#{file.path}:"
        file.lines.sort_by(&:first).each do |_, line|
          if method = line.method_definition
            puts "  #{line.lineno}: #{method.mod}##{method.name}"
          else
            puts "  #{line.lineno}:"
            line.calls.each do |call|
              puts "  - [#{call.index}] #{call.method.mod}##{call.method.name}(#{call.arguments}) => #{call.return_value.inspect} (#{call.method.line.file.path}:#{call.method.line.lineno})"
            end
          end
        end
      end
    end

    def save_as_html(root)
      require 'fileutils'
      require 'pathname'
      require 'json'

      root = Pathname.new(File.expand_path(root))
      zepto = root + 'zepto.js'
      FileUtils.cp(File.expand_path('../zepto.js', __FILE__), root)

      @files.each do |_, file|
        destination_path = Pathname.new(File.join(root, file.path) << '.html')
        destination_path.dirname.mkpath

        content = File.read(file.path)
        content_lines = content.split("\n")
        lineno_indent = content_lines.size.to_s.length

        File.open(destination_path, 'w') do |out|
          out.puts "<html><body><pre>"
          content_lines.each.with_index do |content_line, index|
            out.write "#{(index+1).to_s.rjust(lineno_indent)}: "
            if line = file.lines[index+1]
              if line.method_definition
                out.puts "<span style='font-weight:bold;font-style:italic;'>#{content_line}</span>"
              else
                links = line.calls.map do |call|
                  method_line = call.method.line
                  method_html_file = Pathname.new(File.join(root, method_line.file.path) << '.html')
                  href = "#{method_html_file.relative_path_from(destination_path.dirname)}##{method_line.lineno}"
                  "<a href='#{href}'>#{call.method.mod}##{call.method.name}</a>"
                end
                out.puts "<div class='calls' style='display:inline;'><span id='#{line.lineno}' style='font-weight:bold;'>#{content_line}</span> <span style='display:none;'>#{links.join(' ')}</span></div>"
              end
            else
              out.puts content_line
            end
          end
          out.puts <<-EOS
</pre>
<script src='#{zepto.relative_path_from(destination_path)}'></script>
<script>
  $(document).on('mouseenter', 'div.calls', function (event) {
    $(this).children().last().show();
  });
  $(document).on('mouseleave', 'div.calls', function (event) {
    $(this).children().last().hide();
  });
</script>
</body>
</html>
          EOS
        end
      end
    end
  end
end
