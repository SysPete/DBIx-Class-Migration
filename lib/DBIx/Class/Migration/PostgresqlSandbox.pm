package DBIx::Class::Migration::PostgresqlSandbox;

use Moose;
use Test::postgresql;
use File::Spec::Functions 'catdir', 'catfile';
use File::Path 'mkpath';

has target_dir => (is=>'ro', required=>1);
has schema_class => (is=>'ro', required=>1);
has test_postgresql => (is=>'ro', lazy_build=>1);

  sub _generate_sandbox_dir {
    my $schema_class = (my $self = shift)->schema_class;
    $schema_class =~ s/::/-/g;
    catdir($self->target_dir, lc($schema_class));
  }

sub _build_postgresql {
  my $base_dir = (my $self = shift)->_generate_sandbox_dir;
  my $auto_start = -d $base_dir ? 1:2;
  return Test::mysqld->new(
    auto_start => $auto_start,
    base_dir => $base_dir);
}

sub _write_start {
  my $base_dir = (my $self = shift)->test_postgresql->base_dir;
  mkpath(my $bin = catdir($base_dir, 'bin'));
  open( my $fh, '>', catfile($bin, 'start'))
    || die "Cannot open $bin/start: $!";

  my $mysqld = $self->test_mysqld->{mysqld};
  my $my_cnf = catfile($base_dir, 'etc', 'my.cnf');
  print $fh <<START;
#!/usr/bin/env sh

$mysqld --defaults-file=$my_cnf &
START

  close($fh);

  chmod oct("0755"), catfile($bin, 'start');
}

sub _write_stop {
  my $base_dir = (my $self = shift)->test_postgresql->base_dir;
  mkpath(my $bin = catdir($base_dir, 'bin'));
  open( my $fh, '>', catfile($bin, 'stop'))
    || die "Cannot open $bin/stop: $!";

  my $PIDFILE = $self->test_mysqld->{my_cnf}->{'pid-file'};
  print $fh <<STOP;
#!/usr/bin/env sh

kill \$(cat $PIDFILE)
STOP

  close($fh);

  chmod oct("0755"), catfile($bin, 'stop');
}

sub _write_use {
  my $base_dir = (my $self = shift)->test_postgresql->base_dir;
  mkpath(my $bin = catdir($base_dir, 'bin'));
  open( my $fh, '>', catfile($bin, 'use'))
    || die "Cannot open $bin/use: $!";

  my $SOCKET = $self->test_postgresql->{my_cnf}->{socket};
  my $mysqld = $self->test_postgresql->{mysqld};
  $mysqld =~s/d$//; ## ug. sorry :(

  print $fh <<USE;
#!/usr/bin/env sh

$mysqld --socket=$SOCKET -u root test
USE

  close($fh);

  chmod oct("0755"), catfile($bin, 'use');
}


sub make_sandbox {
  my $base_dir = (my $self = shift)->test_postgresql->base_dir;
  $self->_write_start;
  $self->_write_stop;
  $self->_write_use;

  return "DBI:mysql:test;mysql_socket=$base_dir/tmp/mysql.sock",'root','';
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

DBIx::Class::Migration::PostgresqlSandbox - Autocreate a postgresql sandbox

=head1 SYNOPSIS

    use DBIx::Class::Migration;

    my $migration = DBIx::Class::Migration->new(
      schema_class=>'Local::Schema',
      db_sandbox_class=>'DBIx::Class::Migration::PostgresqlSandbox'),

    $migration->prepare;
    $migration->install;

=head1 DESCRIPTION

This automatically creates a postgresql sandbox in your C<target_dir> that you can
use for initial prototyping, development and demonstration.  If you want to
use this, you will need to add L<Test::postgresql> to your C<Makefile.PL> or your
C<dist.ini> file, and get that installed properly.  It also requires that you
have Postgresql installed locally (although Postgresql does not need to be running, as
long as we can find in $PATH the binary installation).  If your copy of Postgresql
is not installed in a normal location, you might need to locally alter $PATH
so that we can find it.

In addition to the Postgresql sandbox, we create three helper scripts C<start>,
C<stop> and C<use> which can be used to start, stop and open shell level access
to you mysql sandbox.

These helper scripts will be located in a child directory of your C<target_dir>
(which defaults to C<share> under your project root directory).  For example:

    [target_dir]/[schema_class]/bin/[start|stop|use]

If your schema class is C<MyApp::Schema> you should see helper scripts like

    /MyApp-Web
      /lib
        /MyApp
          Schema.pm
          /Schema
            ...
      /share
        /migrations
        /fixtures
        /myapp-schema
          /bin
            start
            stop
            use

This give you a system for installing a sandbox locally for development,
starting and stopping it for use (for example in a web application like one you
might create with L<Catalyst>) and for using it by openning a native C<mysql>
shell (such as if you wish to review the database manually, and run native SQL
queries).

=head1 SEE ALSO

L<DBIx::Class::Migration>, L<DBD::Pg>, L<Test::postgresql>.

=head1 AUTHOR

See L<DBIx::Class::Migration> for author information

=head1 COPYRIGHT & LICENSE

See L<DBIx::Class::Migration> for copyright and license information

=cut


