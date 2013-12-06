# ABSTRACT: Edit files with transaction support
package File::Transaction;
use Moo;
use Types::Standard qw( ArrayRef InstanceOf Int Bool Num Str );
use MooX::HandlesVia;
use File::Transaction::Schema;
use File::Temp;
use File::Copy qw(copy);
use Path::Class qw(file);
use File::HomeDir qw(my_home);
use Time::HiRes;
use Try::Tiny;

has files => (
    is          => 'ro',
    isa         => ArrayRef,
    required    => 1,
    handles_via => 'Array',
    handles     => {
        get_files => 'elements',
    },
);

has timeout => (
    is      => 'ro',
    isa     => Int,
    default => 10,
);

has wake_up => (
    is      => 'ro',
    isa     => Num,
    default => .2,
);

has file_rs => (
    is      => 'lazy',
    isa     => InstanceOf['DBIx::Class::ResultSet'],
    handles => {
        count_files  => 'count',
        search_files => 'search',
    },
);

has db_path => (
    is      => 'ro',
    isa     => Str,
    default => sprintf('%s/.file-transaction/file.db', my_home()),
);

has temp_dir => (
    is  => 'lazy',
    isa => InstanceOf['File::Temp::Dir'],
);

has _in_txn => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
);

sub BUILD {
    my ( $self ) = @_;
    
    my $db_file = file $self->db_path;
    $db_file->parent->mkpath;
}

sub begin {
    my ( $self ) = @_;
    
    return if $self->_in_txn;
    
    $self->_lock;

    foreach my $file ( $self->get_files ) {
        copy $file, $self->temp_dir;
    }
    
    return;
}

sub commit {
    my ( $self ) = @_;
    
    return unless $self->_in_txn;
    
    $self->_unlock;
    return;
}

sub rollback {
    my ( $self ) = @_;

    return unless $self->_in_txn;

    foreach my $file ( $self->get_files ) {
        $file = file $file;
        
        my $original = sprintf '%s/%s', $self->temp_dir, $file->basename;
        
        copy $original, $file;
    }
    
    $self->_unlock;
    return;
}

sub txn_do {
    my ( $self, $sub ) = @_;
    
    my $sub_txn = $self->_in_txn;
    
    $self->begin unless $sub_txn;
    
    my $rv;
    try {
        $rv = $sub->();
    } catch {
        $self->rollback;
        
        die "Transaction failed: $_";
    };
    
    $self->commit unless $sub_txn;
    
    return $rv;
}

sub _lock {
    my ( $self ) = @_;

    my ( $time, $locked ) = ( 0, 0 );

    while ($time < $self->timeout) {
        try {            
            $self->file_rs->result_source->schema->txn_do(sub {
                $self->file_rs->populate([
                    ['file'],
                    map { [$_] } @{$self->files},
                ]);
            });
            
            $locked = 1;
        } catch {
            sleep $self->wake_up;
            $time += $self->wake_up;
        };
        
        last if $locked;
    }
    
    die "Transaction timed out\n" unless $locked;
    
    $self->_in_txn(1);
    
    return;
}

sub _unlock {
    my ( $self ) = @_;
    
    $self->file_rs->result_source->schema->txn_do(sub {
        $self->search_files({file => $self->files})->delete_all;
    });
    
    $self->_in_txn(0);
    
    return;
}

sub _build_temp_dir {
    my ( $self ) = @_;
    
    return File::Temp->newdir;
}

sub _build_file_rs {
    my ( $self ) = @_;
    
    my $schema = File::Transaction::Schema->connect('dbi:SQLite:' . $self->db_path);
    $schema->deploy unless -f $self->db_path;
    return $schema->resultset('File');
}

1;

__END__

=head1 SYNOPSIS

    my $transaction = File::Transaction->new(
        files => [
            '/path/to/file1',
            '/different/path/to/file2',
        ],
    );

    $transaction->txn_do(sub {
        # do something with the files...
        # if an exception is thrown inside this block all files are rolled back
    });

=head1 DESCRIPTION

When editing multiple files it can be desirable to roll them all back to the
inital state when an error occurs. This class aims to provide a simple way to
make that possible.

This class uses an SQLite database to store information about which files are
locked. This is so different instances of this class or even different processes
can lock the same files are ensure they respect each others transactions.

=head1 ATTRIBUTES

=head1 files

    is: ro, isa: ArrayRef, required: 1

The files to use within the transaction.

=head1 db_path

    is: ro, isa: Str, default: <home dir>/.file-transaction/file.db

The path to the SQLite database. The database and path will be created for you
if they don't exist. This uses L<File::HomeDir> to get a cross platform home
directory.

=head1 timeout

    is: ro, isa: Int, default: 10

The time in seconds to wait for a lock before throwing an exception.

=head1 wake_up

    is: ro, isa: Num, default .2

The time in seconds to wait before checking if the files are available for
locking.

=head1 METHODS

=head2 begin

Begins a transaction by first checking if a lock is available then copying the
files to temp directory in case they need to rollback. If a lock isn't available
then this method will continue to try to get a lock until the timeout is
reached.

=head2 commit

Ends the transaction by unlocking the files.

=head2 rollback

Ends the transaction by copying the temporary backup of the files back and then
unlocking the files.

=head2 txn_do

    ( CodeRef $sub )

Automatically begins a transaction then runs $sub. If $sub throwns an exception
then rollback is called for you. If $sub exists normally then commit is called.
