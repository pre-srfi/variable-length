# SRFI nnn: Variable-length integers and strings

by Firstname Lastname, Another Person, Third Person

# Status

Early Draft

# Abstract

This SRFI defines simple procedures to read and write variable-length
integers and strings on binary ports. The formats covered are unsigned
and signed varints; netstrings and their variants; and varint-prefixed
strings.

# Rationale

# Specification

## Unsigned varint encoding

Varints are written in little-endian byte order:

* First write the low 7 bits of the value.
* If the remainder is not zero, then the next 7 bits.
* If the remainder is not zero, then the next 7 bits.
* etc.

All of the written bytes, except for the last, have their high bit set
to 1. If only one byte is written (i.e. the original value is 127 or
less) then it is treated as the last byte, and does not have its high
bit set.

When reading a varint you need to keep track of the left-shift amount.
It is zero for the first byte and increments by 7 for each new byte.

Little-endian byte order means that leading zeros do not present a
problem.

## Signed varint encoding

Signed integers are mapped to unsigned integers using zig-zag
encoding:

* Non-negative signed integers _x = 0, 1, 2, ..._ are mapped to the
  even unsigned integers _2 * x_.

* Negative signed integers _x = -1, -2, -3, ..._ are mapped to the odd
  unsigned integers _1 + 2 * -(x + 1)_.

The resulting unsigned integers are then written using unsigned varint
encoding.

The advantages of zig-zag encoding are:

* It imposes no limit on the magnitude of numbers.

* The amount of space taken grows proportionally to the magnitude of
the number, making it cheap to represent both positive and negative
numbers near zero.

## Varstring encoding

Unsigned varint (number of bytes) followed by the bytes.

## Netstring encoding

Netstrings use `11:hello world,` encoding. The length prefix is ASCII
digits. The delimiting colon and comma are also ASCII. The string
itself does not need to be ASCII; it can contain arbitrary bytes. The
string bytes are not interpreted; there is no escape syntax.

Tagged Netstrings, BitTorrent's Bencode, and Dotted Canonical
S-expressions (DCSexps) use a similar format, but the terminator
(comma) can be different or missing.

## Flushing output ports

None of the write procedures in this SRFI guarantee that the output
port is flushed after writing. In fact, most of the time they should
not flush it. In practice, applications generally need to flush every
time after writing a batch of data to be processed by the receiver.

## Skip things

(*skip-varint-tail* [_port_]) => _count?_

Skips any and all bytes that have the high bit set. Returns the number
of bytes skipped, or `#f` if none.

(*skip-varint* [_port_]) => _count_

Skips any and all bytes that have the high bit set. Then expect one
byte without the high bit set and skip it, raising an error if such a
byte is not found. Returns the number of bytes skipped.

(*skip-varbytes* [_port_]) => _count_

(*skip-netstring* [_port_ _terminator_]) => _count_

## Write varints

(*write-unsigned-varint* _integer_ [_port_])

(*write-signed-varint* _integer_ [_port_])

Writes the given non-negative exact _integer_ to the given byte output
_port_ using unsigned varint encoding.

The integer can be arbitrarily large; if the implementation supports
bignums, it should be able to write them.

Writes the given exact _integer_ to the given byte output _port_ using
signed varint encoding.

The integer can be arbitrarily small or large; if the implementation
supports bignums, it should be able to write them.

## Read varints

(*read-unsigned-varint* [_port_ _max-value_]) => _integer_

(*read-signed-varint* [_port_ _min-value_ _max-value_]) => _integer_

Reads a non-negative exact integer from the given byte input _port_
assuming unsigned varint encoding.

If end-of-file is reached before reading any bytes, an end-of-file
object is returned. If one or more continuation bytes are read but
end-of-file is reached before a final byte, an exception is raised.

If _max-value_ is supplied and not `#f`, it has to be a
non-negative exact integer. An error is raised when reading a number
greater than _max-value_. The reader may stop keeping track of the
number once it is clear that its magnitude is getting ouf of bounds.
It is undefined whether the port position lies inside or past the
varint in this case; call *skip-varint-tail* to ensure the varint has
been skipped.

Any number returned by this procedure is guaranteed to be a fixnum
when _max-value_ is a fixnum. Otherwise a bignum may be returned.

Reads an exact integer from the given byte input _port_ assuming
signed varint encoding.

If end-of-file is reached before reading any bytes, an end-of-file
object is returned. If one or more continuation bytes are read but
end-of-file is reached before a final byte, an exception is raised.

If _min-value_ and/or _max-value_ are supplied and not `#f`, they have
to be exact integers. An error is raised when reading a number less
than _min-value_ or greater than _max-value_. The reader may stop
keeping track of the number once it is clear that its magnitude is
getting ouf of bounds. It is undefined whether the port position lies
inside or past the varint in this case; call *skip-varint-tail* to
ensure the varint has been skipped.

Any number returned by this procedure is guaranteed to be a fixnum
when _min-value_ and _max-value_ are both fixnums. Otherwise a bignum
may be returned.

## Bytevector procedures

(*read-varbytes* [_port_ _max-bytes_]) => bytevector

(*read-netstring-bytes* [_port_ _max-bytes_ _terminator_]) => bytevector

Reads an unsigned varint giving the number of bytes from the given
byte input _port_. Then reads exactly that many bytes into a fresh
bytevector and returns it.

_terminator_ can be any ASCII char (0..127). If not supplied or `#f`,
a comma which is the standard netstring terminator.

(*write-varbytes* _bytevector_ [_port_ _start_ _end_])

(*write-netstring-bytes* _bytevector_ [_port_ _start_ _end_])

Writes an unsigned varint giving the length of _bytevector_, followed
immediately by the contents of _bytevector_.

## String procedures

(*read-varstring* _port_ [_max-bytes_ _encoding_ _invalid_]) => _string_

(*read-netstring* _port_ [_max-bytes_ _encoding_ _invalid_]) => _string_

(*write-varstring* _string_ [_port_ _start_ _end_ _encoding_ _invalid_])

(*write-netstring* _string_ [_port_ _start_ _end_ _encoding_ _invalid_])

Reads/writes a varstring or a netstring.

_string_ is a Scheme string.

_port_ is a binary port.

When reading, _max-bytes_ gives the maximum number of _bytes_ to read. If
longer, an exception is raised. If omitted of `#f`, no limit.

When writing, _start_ and _end_ give bounds for writing only a part of
_string_. If omitted or `#f`, they default to 0 and the string length,
respectively.

_encoding_ says which character encoding to use. If omitted or `#f` it
defaults to UTF-8.

_invalid_ says what to do when encountering character encoding errors.
If omitted or `#f` then invalid characters raise an exception. If a
character or string, each invalid character is replaced with it.

A trivial implementation can call the bytevector procedures in this
SRFI. A fast implementation will be able to avoid allocating the
intermediate bytevector.

# Implementation

# Acknowledgements

# References

https://golang.org/src/encoding/binary/varint.go

# Copyright

Copyright (C) Firstname Lastname (20XY).

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
