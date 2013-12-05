# NAME

File::Transaction - Edit files with transaction support

# VERSION

version 0.001

# SYNOPSIS

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

# DESCRIPTION

When editing multiple files it can be desirable to roll them all back to the
inital state when an error occurs. This class aims to provide a simple way to
make that possible.

This class uses an SQLite database to store information about which files are
locked. This is so different instances of this class or even different processes
can lock the same files are ensure they respect each others transactions.

# ATTRIBUTES

# files

    is: ro, isa: ArrayRef, required: 1

The files to use within the transaction.

# db\_path

    is: ro, isa: Str, default: <home dir>/.file-transaction/file.db

The path to the SQLite database. The database and path will be created for you
if they don't exist. This uses [File::HomeDir](http://search.cpan.org/perldoc?File::HomeDir) to get a cross platform home
directory.

# timeout

    is: ro, isa: Int, default: 10

The time in seconds to wait for a lock before throwing an exception.

# wake\_up

    is: ro, isa: Num, default .2

The time in seconds to wait before checking if the files are available for
locking.

# METHODS

## begin

Begins a transaction by first checking if a lock is available then copying the
files to temp directory in case they need to rollback. If a lock isn't available
then this method will continue to try to get a lock until the timeout is
reached.

## commit

Ends the transaction by unlocking the files.

## rollback

Ends the transaction by copying the temporary backup of the files back and then
unlocking the files.

## txn\_do

    ( CodeRef $sub )

Automatically begins a transaction then runs $sub. If $sub throwns an exception
then rollback is called for you. If $sub exists normally then commit is called.

# AUTHOR

Andy Gorman <andyg@apacesystems.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Apace Systems Corporation.  No
license is granted to other entities.
