use strict;
use warnings;
use Test::More;
use Test::Exception;
use FindBin;
use File::Slurp;
use File::Temp;
use File::Copy::Recursive qw(rcopy);
use Try::Tiny;
use File::Transaction;

my $temp_dir = File::Temp->newdir;
rcopy "$FindBin::Bin/etc", $temp_dir;

my $txn = File::Transaction->new(
    files   => [
        "$temp_dir/a",
        "$temp_dir/b",
    ],
);

lives_ok(sub {
    $txn->begin;
    write_file "$temp_dir/a", 'modified';
    $txn->rollback;
}, 'rollback');

is read_file("$temp_dir/a"), 'hello'
    => 'rollback ok';

lives_ok(sub {
    $txn->begin;
    write_file "$temp_dir/a", 'modified';
    $txn->commit;
}, 'commit');

is read_file("$temp_dir/a"), 'modified'
    => 'commit ok';

lives_ok(sub {
    $txn->txn_do(sub {
        write_file "$temp_dir/a", 'modified_again';
    });
}, 'txn_do (commit)');

is read_file("$temp_dir/a"), 'modified_again'
    => 'txn_do (commit) ok';

lives_ok(sub {
    try {
        $txn->txn_do(sub {
            write_file "$temp_dir/a", 'modified_thrice';
            die;
        });
    };
}, 'txn_do (rollback)');

is read_file("$temp_dir/a"), 'modified_again'
    => 'txn_do (rollback) ok';


my $txn2 = File::Transaction->new(
    timeout => .2,
    wake_up => .1,
    files   => [
        "$temp_dir/a",
        "$temp_dir/b",
    ],
);

$txn->begin;

dies_ok(sub {
    $txn2->begin;
}, 'timeout');

done_testing();
