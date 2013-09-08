# ruby-trace

The purpose of this tool is to generate HTML that guides you through the calls being made in a
codebase, making it easier to find your way around a project you’re not familiar with.

**As of yet this is only a very rough prototype, not feature complete, and definitely not pretty.**

Nonetheless, patches, especially those that make it prettier, will be accepted. As do any of the
items in the TODO, including the full rewrite. If you do start work on one of those TODO items,
create a ticket to let me know.


## Usage

```ruby
require 'ruby-trace'

tracer = RubyTrace::Trace.new
tracer.trace do
  # Perform work that should be traced.
end
tracer.save_as_html('traces')
```


## Example HTML

Example output can be found [here](http://alloy.github.io/ruby-trace/#134287), which was generated from
[this](https://github.com/CocoaPods/CocoaPods/commit/efe30b868865af10d810f5b5c908cf634ce7d8c0)
CocoaPods commit.


## License

Available under the MIT license.

```
Copyright (c) 2013 Eloy Durán <eloy.de.enige@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
