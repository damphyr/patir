# patir

[![CircleCI](https://circleci.com/gh/damphyr/patir/tree/main.svg?style=svg)](https://circleci.com/gh/damphyr/patir/tree/main)

[patir](http://patir.rubyforge.org) provides code to enable project automation tasks:

* an adjusted logging format for the built-in logger of Ruby
* a command abstraction with a platform independent implementation for running
  shell commands or Ruby code
* sequences of commands using the same command abstraction as single commands.
* a Configuration class and format for loading configuration files written in Ruby.

## Why?

Some of the same things are used again and again and shouldn't be rewritten
every time.

The command abstraction is the primary and most used feature of this gem. The
logger creation convenience method and the adjusted logger formatter are used
the least.

## Dependencies

The platform independence for shell command execution is achieved with the
help of the [systemu](https://github.com/ahoward/systemu) gem.

Everything else is written in pure Ruby.

## Install

 gem install patir

## License

(The MIT License)

Copyright (c) 2007-2021 Vassilis Rizopoulos

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
