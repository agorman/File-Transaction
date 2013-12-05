use utf8;
package File::Transaction::Schema::Result::File;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

File::Transaction::Schema::Result::File

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<file>

=cut

__PACKAGE__->table("file");

=head1 ACCESSORS

=head2 file_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 file

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "file_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "file",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</file_id>

=back

=cut

__PACKAGE__->set_primary_key("file_id");


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2013-12-05 12:43:37
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:8ioh37+OmSZS8zlecbb0tg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
