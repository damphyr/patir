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

(The Ruby License)

patir is copyright (c) 2007-2012 Vassilis Rizopoulos

You can redistribute it and/or modify it under either the terms of the GPL
(see COPYING.txt file), or the conditions below:

  1. You may make and give away verbatim copies of the source form of the
     software without restriction, provided that you duplicate all of the
     original copyright notices and associated disclaimers.

  2. You may modify your copy of the software in any way, provided that
     you do at least ONE of the following:

       a) place your modifications in the Public Domain or otherwise
          make them Freely Available, such as by posting said
	  modifications to Usenet or an equivalent medium, or by allowing
	  the author to include your modifications in the software.

       b) use the modified software only within your corporation or
          organization.

       c) rename any non-standard executables so the names do not conflict
	  with standard executables, which must also be provided.

       d) make other distribution arrangements with the author.

  3. You may distribute the software in object code or executable
     form, provided that you do at least ONE of the following:

       a) distribute the executables and library files of the software,
	  together with instructions (in the manual page or equivalent)
	  on where to get the original distribution.

       b) accompany the distribution with the machine-readable source of
	  the software.

       c) give non-standard executables non-standard names, with
          instructions on where to get the original software distribution.

       d) make other distribution arrangements with the author.

  4. You may modify and include the part of the software into any other
     software (possibly commercial).  But some files in the distribution
     are not written by the author, so that they are not under this terms.

     They are gc.c(partly), utils.c(partly), regex.[ch], st.[ch] and some
     files under the ./missing directory.  See each file for the copying
     condition.

  5. The scripts and library files supplied as input to or produced as 
     output from the software do not automatically fall under the
     copyright of the software, but belong to whomever generated them, 
     and may be sold commercially, and may be aggregated with this
     software.

  6. THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
     IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
     WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
     PURPOSE.