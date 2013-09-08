# TODO
#
# ### Trace code
#
# * Rewrite (at least) hot paths in a C extension.
# * Get sender mod+name of call and use that to link to callers instead of path. This can only be done in C.
#
# * Collecting call return values is not working right yet.
# * Collecting call arguments works fine, but isn't needed yet and needs memory usage optimization.
# * Show call arguments and returns values in report.
#
# ### HTML
#
# * Fix div.line getting taller when calls are being shown (on hover).
#

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
          raise "[method definition on line] Mod/name inconsistency"
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
      #attr_accessor :method, :from_line, :index, :arguments, :return_value
      attr_accessor :method, :from_line, :index, :arguments
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
      #stack = []
      #trace = TracePoint.new(:call, :return) do |tp|
      trace = TracePoint.new(:call) do |tp|
        next if tp.path == __FILE__
        case tp.event
        when :call
          if from_line = line_from_call_trace_point(tp)
            to_line = line_for_path_and_lineno(tp.path, tp.lineno)
            method = to_line.method_definition_with_mod_and_name(tp.defined_class, tp.method_id)
            #call = method.add_caller(from_line, @call_index, arguments_from_call_trace_point(tp))
            call = method.add_caller(from_line, @call_index, nil)
            from_line.add_call(call)
            @call_index += 1
            #stack << call
          end
        #when :return
          #call = stack.last
          #if call && call.method.name == tp.method_id && call.method.mod == tp.defined_class
            #call.return_value = tp.return_value
            #stack.pop
          #else
            #raise "[return] Stack inconsistency."
          #end
        end
      end
      trace.enable
      yield
      #raise "[finished] Stack inconsistency." unless stack.empty?
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
              #puts "  - [#{call.index}] #{call.method.mod}##{call.method.name}(#{call.arguments}) => #{call.return_value.inspect} (#{call.method.line.file.path}:#{call.method.line.lineno})"
              puts "  - [#{call.index}] #{call.method.mod}##{call.method.name} (#{call.method.line.file.path}:#{call.method.line.lineno})"
            end
          end
        end
      end
    end

    def save_as_html(root)
      STDOUT.sync = true
      puts "Generating trace html:"

      require 'fileutils'
      require 'pathname'
      require 'json'

      root = Pathname.new(File.expand_path(root))
      root.mkpath

      zepto = root + 'zepto.js'
      FileUtils.cp(File.expand_path('../zepto.js', __FILE__), root)

      @files.each do |_, file|
        print "#{file.path}: "
        destination_path = Pathname.new(File.join(root, file.path) << '.html')
        destination_path.dirname.mkpath

        content = File.read(file.path)
        content_lines = content.split("\n")
        lineno_indent = content_lines.size.to_s.length

        File.open(destination_path, 'w') do |out|
          out.puts <<-EOS
<html>
<head>
<style type="text/css">
.highlight { background-color: rgb(255, 255, 204); }
pre { display: inline; }
div.calls { display: inline; }
span.method_definition { font-weight: bold; }
span.method_call { font-weight: bold; }
div.line a { font-size: 12px; }
</style>
</head>
<body>
          EOS
          content_lines.each.with_index do |content_line, index|
            out.write "<div class='line' id='#{index+1}'><pre>#{(index+1).to_s.rjust(lineno_indent)}: </pre>"
            content_line = "<pre>#{content_line}</pre>"
            if line = file.lines[index+1]
              if line.method_definition
                links = line.method_definition.callers.map do |call|
                  method_line = call.from_line
                  method_html_file = Pathname.new(File.join(root, method_line.file.path) << '.html')
                  href = "#{method_html_file.relative_path_from(destination_path.dirname)}##{method_line.lineno}"
                  "<a href='#{href}'>#{method_line.file.path}:#{method_line.lineno}</a>"
                end
                out.write "<div class='calls'><span class='method_definition'>#{content_line}</span> <span style='display:none;'>#{links.join(' ')}</span></div>"
              else
                links = line.calls.map do |call|
                  method_line = call.method.line
                  method_html_file = Pathname.new(File.join(root, method_line.file.path) << '.html')
                  href = "#{method_html_file.relative_path_from(destination_path.dirname)}##{method_line.lineno}"
                  "<a href='#{href}'>#{call.method.mod}##{call.method.name}</a>"
                end
                out.write "<div class='calls'><span class='method_call'>#{content_line}</span> <span style='display:none;'>#{links.join(' ')}</span></div>"
              end
            else
              out.write content_line
            end
            out.puts "</div>"
            print '.'
          end
          out.puts <<-EOS
<script src='#{zepto.relative_path_from(destination_path.dirname)}'></script>
<script>
  var update_highlight = function() {
    $('div.highlight').removeClass('highlight');
    var hash = document.location.hash;
    if (hash.length > 0) $(hash).addClass('highlight');
  };
  $(document).on('hashchange', update_highlight);
  update_highlight();

  $(document).on('mouseenter', 'div.calls', function() {
    $(this).children().last().show();
  });
  $(document).on('mouseleave', 'div.calls', function() {
    $(this).children().last().hide();
  });
</script>
</body>
</html>
          EOS
          print "\n"
        end
      end
    end
  end
end
