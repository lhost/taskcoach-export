#!/usr/bin/perl -w

#
# taskcoach-export.pl
#
# Developed by Lubomir Host <lubomir.host AT gmail.com>
# Copyright (c) 2009-2014 Lubomir Host
# Licensed under terms of GNU General Public License.
# All rights reserved.
#
# Changelog:
# 2009-10-29 - created
#

use strict;

$| = 1;

use FindBin;
use Getopt::Long;
use XML::Simple;
use DateTime;
use DateTime::Duration;
use DateTime::Format::MySQL;
use Data::Dumper;
use File::Basename;

use lib "$FindBin::Bin";
use TaskCoach;

# Color support {{{
my $WIN = ($^O eq 'MSWin32') ? 1 : 0;
## Test for color support.
eval { require Term::ANSIColor; };
my $HAS_COLOR = $@ ? 0 : 1;
$HAS_COLOR = 0 if $WIN;
# }}}

use vars qw(
	$DEBUG
	$do_help
	$do_worklog
	$do_stat
	$total_minutes_spend
	$xs $x
	%config
);

sub help();
sub do_stat($$$);
sub do_worklog($$$);

sub help() { system('perldoc', $0) == 0 or die "ERROR: $?"; }

$DEBUG = 0;

## Default Config Values
my %config = (
	color	=> 1,
);

$total_minutes_spend = 0;

my $res = GetOptions(
	'help|h'			=> \$do_help,
	'worklog'			=> \$do_worklog,
	'stat'				=> \$do_stat,
	'color!'			=> \$config{color}
);

# Color support {{{
if ($HAS_COLOR and not $config{color}) {
	$HAS_COLOR = 0;
}

if ($HAS_COLOR) {
	import Term::ANSIColor ':constants';
}
else {
	*RESET     = sub { };
	*YELLOW    = sub { };
	*RED       = sub { };
	*GREEN     = sub { };
	*BLUE      = sub { };
	*WHITE     = sub { };
	*BOLD      = sub { };
	*MAGENTA   = sub { };
}

my $RESET   = RESET()   || '';
my $YELLOW  = YELLOW()  || '';
my $RED     = RED()     || '';
my $GREEN   = GREEN()   || '';
my $BLUE    = BLUE()    || '';
my $WHITE   = WHITE()   || '';
my $BOLD    = BOLD()    || '';
my $MAGENTA = MAGENTA() || '';

# }}}

#
# Main block {{{
#

if ($do_help) {
	help();
	exit 0;
}

$xs	= XML::Simple->new(
	KeyAttr		=> {
	},
	ForceContent	=> {
		task		=> 'id',
	},
	ForceArray	=> [ qw( task effort category ) ],
);
$x	= $xs->XMLin($ARGV[0]);

if ($do_stat) {
	if (scalar(@ARGV) < 3) {
		help();
		exit 1;
	}
	do_stat($x, $ARGV[1], $ARGV[2]);
}
elsif ($do_worklog) {
	if (scalar(@ARGV) < 3) {
		help();
		exit 1;
	}
	do_worklog($x, $ARGV[1], $ARGV[2]);
}
else {
	help();
	exit 1;
}

#
# Main block }}}
#

sub do_stat($$$)
{ # {{{
	my ($x, $date, $subject) = @_;
	my $exported_tasks = {};

	my ($year, $month) = ($date =~ m/^(\d\d\d\d)-(\d\d)$/);

	unless (defined($year) and defined($month)) {
		help();
		exit 1;
	}

	# compute start and end time
	my $base_dt = DateTime->new( year => $year, month => $month );
	my $one_month_dur = DateTime::Duration->new(months => 1);
	my $start_time	= $base_dt->strftime('%Y%m%d000000');
	my $end_time	= ($base_dt + $one_month_dur)->strftime('%Y%m%d000000');

	my $last_day = DateTime->last_day_of_month(year => $year, month => $month)->strftime('%d');

	#die Dumper($last_day, { last_day => DateTime->last_day_of_month(year => $year, month => $month)->strftime('%Y%m%d') });
	print "# $year-$month - $last_day days\n";

	#print Dumper($x);
	foreach my $tt (@{$x->{task}}) {
		$total_minutes_spend += stat_task($tt, $exported_tasks, $subject, [ $tt->{subject} ], $start_time, $end_time);
	}

	# header
	my $separator = "+----+-----+--------+--------+--------+-------+------+\n";
	print $separator;
	print "| day| dow | 00:00  | 08:00  | 16:00  | hours | mins |\n";
	print $separator;
	# day list
	foreach my $d (1..$last_day) {
		my $dow = $base_dt->day_abbr();
		printf "| %2d | %s |", $d, $dow;
		my $day_minutes_spend = 0;
		foreach my $h (0..23) {
			my $m = ($exported_tasks->{ $base_dt->ymd('') }->{ $h } || 0);
			$day_minutes_spend += $m;
			#printf "%2d ", $m;
			# symbols: .,-+x*
			print
				$m > 60 ? "${MAGENTA}*" :
				$m > 50 ? "${GREEN}*" :
				$m > 40 ? "${YELLOW}*" :
				$m > 30 ? "${YELLOW}*" :
				$m > 20 ? "${RED}*" :
				$m > 10 ? "${RED}*" :
				"${RESET}.";
			print "$RESET|" if ( ($h % 8) == 7);
		}
		my $day_spend = DateTime::Duration->new(minutes => $day_minutes_spend);
		my $day_hours_spend = $day_spend->in_units('hours');

		printf " %s%02d:%02d |  %3d%s |\n",
			($day_minutes_spend > 480 ? $GREEN :
				$day_minutes_spend > 300 ? $YELLOW :
				$day_minutes_spend > 60  ? $RED : $RESET),
			$day_hours_spend,
			$day_minutes_spend - 60 * $day_hours_spend,
			$day_minutes_spend, $RESET;


		# week separator
		print $separator if ($dow eq 'Sun');

		$base_dt->add( days => 1 );
	}
	# footer
	print $separator if ($base_dt->day_abbr() ne 'Mon');

	my $total_spend = DateTime::Duration->new(minutes => $total_minutes_spend);
	my $total_hours_spend = $total_spend->in_units('hours');

	print "TOTAL: ", sprintf('%02d:%02d',
		$total_hours_spend,
		$total_minutes_spend - 60 * $total_hours_spend),
		" hours ($total_minutes_spend mins)\n";

} # }}}

sub do_worklog($$$)
{ # {{{
	my ($x, $date, $subject) = @_;
	my $exported_tasks = {};

	my ($year, $month) = ($date =~ m/^(\d\d\d\d)-(\d\d)$/);

	unless (defined($year) and defined($month)) {
		help();
		exit 1;
	}

	# compute start and end time
	my $base_dt = DateTime->new( year => $year, month => $month );
	my $one_month_dur = DateTime::Duration->new(months => 1);
	my $start_time	= $base_dt->strftime('%Y%m%d000000');
	my $end_time	= ($base_dt + $one_month_dur)->strftime('%Y%m%d000000');

	#print Dumper($x);
	foreach my $tt (@{$x->{task}}) {
		$total_minutes_spend += export_task($tt, $exported_tasks, $subject, [ $tt->{subject} ], $start_time, $end_time);
	}

	#warn Dumper($exported_tasks);
	foreach my $d (sort keys %{$exported_tasks}) {
		foreach my $t (sort keys %{$exported_tasks->{$d}}) {
			my $x = $exported_tasks->{$d}->{$t};
			print "$d - $x->{duration} mins - $t\n";
			foreach my $desc (@{ $x->{desc} }) {
				$desc =~ s/[\r\n]+/\n\t  /g;
				$desc =~ s/^\s+//g;
				$desc =~ s/\s+$//g;
				next if ($desc eq '');
				print "\t* $desc\n";
			}
		}
	}

	my $total_spend = DateTime::Duration->new(minutes => $total_minutes_spend);
	my $total_hours_spend = $total_spend->in_units('hours');

	print "TOTAL: ", sprintf('%02d:%02d',
		$total_hours_spend,
		$total_minutes_spend - 60 * $total_hours_spend),
		" hours ($total_minutes_spend mins)\n";

} # }}}

__END__

=head1 NAME

taskcoach-export.pl - export your worklog from Task Coach to text files

=head1 SYNOPSIS

  taskcoach-export.pl   --worklog   tasks.tsk   YYYY-MM   subject
  taskcoach-export.pl   --worklog   ~/work/Platon/tasks/tasks.tsk   `date '+%Y-%m'`   Platon
  taskcoach-export.pl   --stat      ~/work/Platon/tasks/tasks.tsk   `date '+%Y-%m'`   Platon

=head1 DESCRIPTION

Make text output of your task manager "Task Coach"

=head1 OPTIONS

	--help
	--worklog
	--stat
	--color

=head1 SEE ALSO

See README.md and TaskCoach http://taskcoach.org/

=head1 AUTHORS

Lubomir Host <lubomir.host AT gmail.com>

=cut

# vim: ts=4 fdm=marker fdl=0 fdc=3

