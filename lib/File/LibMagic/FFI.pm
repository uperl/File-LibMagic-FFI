package File::LibMagic::FFI;

use strict;
use warnings;
use v5.10;
use FFI::Raw;
use DynaLoader;
use constant {
  MAGIC_NONE              => 0x000000,
  MAGIC_MIME              => 0x000410, #MIME_TYPE | MIME_ENCODING,
};

# ABSTRACT: Determine MIME types of data or files using libmagic
# VERSION

=head1 SYNOPSIS

 use File::LibMagic;
 
 my $magic = File::LibMagic->new;
 
 # prints a description like "ASCII text"
 say $magic->describe_filename('path/to/file');
 say $magic->describe_contents('this is some data');
 
 # Prints a MIME type like "text/plain; charset=us-ascii"
 say $magic->checktype_filename('path/to/file');
 say $magic->checktype_contents('this is some data');

=head1 DESCRIPTION

This module is a simple Perl interface to C<libmagic>.  It provides the same full undeprecated interface as L<File::LibMagic>, but it uses L<FFI::Raw> instead of C<XS> for
its implementation, and thus can be used without a compiler.

=cut

my $lib = DynaLoader::dl_findfile("magic");

unless(defined $lib)
{
  require File::Glob;
  require File::Spec;
  foreach my $dir (@DynaLoader::dl_library_path)
  {
    my($try) = File::Glob::bsd_glob(File::Spec->catfile($dir, "libmagic.so*"));
    if(defined $try && -f $try)
    {
      $lib = $try;
      last;
    }
  }
}

die "unable to find libmagic" unless -f $lib;

my $magic_open = FFI::Raw->new(
  $lib, 'magic_open',
  FFI::Raw::ptr,
  FFI::Raw::int,
);

my $magic_error = FFI::Raw->new(
  $lib, 'magic_error',
  FFI::Raw::str,
  FFI::Raw::ptr,
);

my $magic_load = FFI::Raw->new(
  $lib, 'magic_load',
  FFI::Raw::int,
  FFI::Raw::ptr, FFI::Raw::str,
);

my $magic_file = FFI::Raw->new(
  $lib, 'magic_file',
  FFI::Raw::str,
  FFI::Raw::ptr, FFI::Raw::str,
);

my $magic_setflags = FFI::Raw->new(
  $lib, 'magic_setflags',
  FFI::Raw::void,
  FFI::Raw::ptr, FFI::Raw::int,
);

my $magic_buffer = FFI::Raw->new(
  $lib, 'magic_buffer',
  FFI::Raw::str,
  FFI::Raw::ptr, FFI::Raw::ptr, FFI::Raw::int,
);

my $magic_check = FFI::Raw->new(
  $lib, 'magic_check',
  FFI::Raw::int,
  FFI::Raw::ptr, FFI::Raw::str,
);

my $magic_compile = FFI::Raw->new(
  $lib, 'magic_compile',
  FFI::Raw::int,
  FFI::Raw::ptr, FFI::Raw::str,
);

my $magic_close = FFI::Raw->new(
  $lib, 'magic_close',
  FFI::Raw::void,
  FFI::Raw::ptr,
);

=head1 API

This module provides an object-oriented API with the following methods:

=head2 new

 my $magic = File::LibMagic->new;
 my $magic = File::LibMagic->new('/etc/magic');

Creates a new File::LibMagic::FFI object.

Using the object oriented interface provides an efficient way to repeatedly determine the magic of a file.

This method takes an optional argument containing a path to the magic file.  If the file doesn't exist, this will throw an exception.

If you don't pass an argument, it will throw an exception if it can't find any magic files at all.

=cut

sub new
{
  my($class, $magic_file) = @_;
  return bless { magic_file => $magic_file }, $class;
}

sub _mime_handle
{
  my($self) = @_;
  return $self->{mime_handle} ||= do {
    my $handle = $magic_open->call(MAGIC_MIME);
    $magic_load->call($handle, $self->{magic_file});
    $handle;
  };
}

sub _describe_handle
{
  my($self) = @_;
  return $self->{describe_handle} ||= do {
    my $handle = $magic_open->call(MAGIC_NONE);
    $magic_load->call($handle, $self->{magic_file});
    $handle;
  };
}

sub DESTROY
{
  my($self) = @_;
  $magic_close->call($self->{magic_handle}) if defined $self->{magic_handle};
  $magic_close->call($self->{mime_handle}) if defined $self->{mime_handle};
}

=head2 checktype_contents

 my $mime_type = $magic->checktype_contents($data);

Returns the MIME type of the data given as the first argument.  The data can be passed as a plain scalar or as a reference to a scalar.

This is the same value as would be returned by the C<file> command with the C<-i> option.

=cut

sub checktype_contents
{
  my $content = ref $_[1] ? ${$_[1]} : $_[1];
  my $ptr = FFI::Raw::MemPtr->new_from_buf($content, length $content);
  $magic_buffer->call($_[0]->_mime_handle, $ptr, length $content);
}

=head2 checktype_filename

 my $mime_type = $magic->checktype_filename($filename);

Returns the MIME type of the given file.

This is the same value as would be returned by the C<file> command with the C<-i> option.

=cut

sub checktype_filename
{
  $magic_file->call($_[0]->_mime_handle, $_[1]);
}

=head2 describe_contents

 my $description = $magic->describe_contents($data);

Returns a description (as a string) of the data given as the first argument. The data can be passed as a plain scalar or as a reference to a scalar.

This is the same value as would be returned by the C<file> command with no options.

=cut

sub describe_contents
{
  my $content = ref $_[1] ? ${$_[1]} : $_[1];
  my $ptr = FFI::Raw::MemPtr->new_from_buf($content, length $content);
  $magic_buffer->call($_[0]->_describe_handle, $ptr, length $content);
}

=head2 describe_filename

 my $description = $magic->describe_filename($filename);

Returns a description (as a string) of the given file.

This is the same value as would be returned by the C<file> command with no options.

=cut

sub describe_filename
{
  $magic_file->call($_[0]->_describe_handle, $_[1]);
}

=head1 DEPRECATED APIS

The FFI version does not support the deprecated APIs that L<File::LibMagic> does.

=head2 SEE ALSO

=over 4

=item L<File::LibMagic>

=item L<FFI::Raw>

=back

=cut

1;
