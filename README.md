# patir

[![Build Status](https://secure.travis-ci.org/damphyr/patir.png)](http://travis-ci.org/damphyr/patir)

[patir](http://patir.rubyforge.org) provides code to enable project automation tasks:

 * A logging format for ruby's built-in Logger
 * A command abstraction with a platform independent implementation for running shell commands and ruby code
 * Command sequences using the same command abstraction as single commands.
 * Configuration format for configuration files written in ruby.

## Why?
We've been using the same things again and again and can't be bothered to code it anew every time.

The command abstraction has been used the most, the Logger defaults and formatting the least.

## Dependencies
The platform independence for shell commands is achieved with the help of the [systemu](https://github.com/ahoward/systemu) gem.

Everything else is pure Ruby.

## Install

 gem install patir

## License

(The MIT License)

Copyright (c) 2007-2012 Vassilis Rizopoulos

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
