#
# TaskCoach.pm
#
# Developed by Lubomir Host 'rajo' <rajo AT platon.sk>
# Copyright (c) 2014 Lubomir Host
# Licensed under terms of GNU General Public License.
# All rights reserved.
#
# Changelog:
# 2014-09-19 - created
#

package TaskCoach;

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT $AUTOLOAD $DEBUG);

@ISA		= qw(Exporter);
@EXPORT		= qw( stat_task export_task );
$VERSION	= "0.1";
$DEBUG		= 0;

sub stat_task($$$$$$);
sub export_task($$$$$$);

sub new
{ #{{{
    my $this  = shift;
    my $class = ref($this) || $this;
    my $self  = {};

    bless $self, $class;

    return $self;
} # }}}

sub export_task($$$$$$)
{ # {{{
	my ($t, $exported_tasks, $subject, $path, $start_time, $end_time) = @_;
	my $total_minutes_spend = 0;

	return(0) unless defined $t;

	#print Dumper(scalar(@$path), join('/', @$path), $path, $subject); # filter subject task tree only
	return(0) if (join('/', @$path) !~ m/^$subject/); # filter subject task tree only

	#@ print "\t" x (scalar(@$path) -  1), ' / ', $$path[scalar(@$path) - 1], "\n";
	if (exists($t->{effort})) {
		my @e = grep { exists($_->{stop}) and exists($_->{start}) } @{$t->{effort}};
		#@ my $prefix = "\t" x (scalar(@$path) -  0);
		#@ print $prefix, scalar(@e), " efforts\n";
		foreach my $ee (@e) {
			my $s_e = $ee->{start};
			$s_e =~ s/\D//g;
			if ($s_e >= $start_time and $s_e < $end_time) {
				my $dt_s =DateTime::Format::MySQL->parse_datetime($ee->{start});
				my $dt_e =DateTime::Format::MySQL->parse_datetime($ee->{stop});
				my $duration = $dt_e - $dt_s;
				my $dur_mins = $duration->delta_minutes();
			   	my $dur_secs = $duration->delta_seconds();
				if ($dur_secs > 15 and $dur_mins <= 15) { # short duration round to whole minute up
					$dur_mins += 1;
				}
				$total_minutes_spend += $dur_mins;
				#print Dumper($duration);
				#print $dt_s->strftime('%Y-%m-%d'), " - $dur_mins mins - ", join(' / ', @$path), "\n";
				#print "\t* ", ($ee->{description}->{content} ||''), "\n";
				my $t = $dt_s->strftime('%Y-%m-%d');
				my $p = join(' / ', @$path);
				$exported_tasks->{$t}->{$p}->{duration} ||= 0;
				$exported_tasks->{$t}->{$p}->{duration} +=  $dur_mins;
				push @{$exported_tasks->{$t}->{$p}->{desc}}, ($ee->{description}->{content} ||'');
				#print "$ee->{start} - $ee->{stop}";
			}
			#@ print $prefix, "* ", ($ee->{description}->{content} ||''), "\n";
		}
	}

	foreach my $tt (@{$t->{task}}) {
		$total_minutes_spend += export_task($tt, $exported_tasks, $subject, [ @$path, $tt->{subject} ], $start_time, $end_time);
	}

	return $total_minutes_spend;

} # }}}

sub stat_task($$$$$$)
{ # {{{
	my ($t, $exported_tasks, $subject, $path, $start_time, $end_time) = @_;
	my $total_minutes_spend = 0;

	return(0) unless defined $t;

	#print Dumper(scalar(@$path), join('/', @$path), $path, $subject); # filter subject task tree only
	return(0) if (join('/', @$path) !~ m/^$subject/); # filter subject task tree only

	#@ print "\t" x (scalar(@$path) -  1), ' / ', $$path[scalar(@$path) - 1], "\n";
	if (exists($t->{effort})) {
		my @e = grep { exists($_->{stop}) and exists($_->{start}) } @{$t->{effort}};
		#@ my $prefix = "\t" x (scalar(@$path) -  0);
		#@ print $prefix, scalar(@e), " efforts\n";
		foreach my $ee (@e) {
			my $s_e = $ee->{start};
			$s_e =~ s/\D//g;
			if ($s_e >= $start_time and $s_e < $end_time) {
				my $dt_s = DateTime::Format::MySQL->parse_datetime($ee->{start});
				my $dt_e = DateTime::Format::MySQL->parse_datetime($ee->{stop});

				my ($date_s, $h_s, $m_s, $s_s) = ($dt_s->ymd(''), $dt_s->hour(), $dt_s->minute(), $dt_s->second());
				my ($date_e, $h_e, $m_e, $s_e) = ($dt_e->ymd(''), $dt_e->hour(), $dt_e->minute(), $dt_e->second());

				print "start: ", $dt_s->strftime('%Y-%m-%d %H:%M:%S'), "\n" if ($DEBUG);
				print "  end: ", $dt_e->strftime('%Y-%m-%d %H:%M:%S'), "\n" if ($DEBUG);

				if ($date_e > $date_s) { # over-midnight work
					#
					# until midnight
					#
					print "exported_tasks->{ $date_s }->{ $h_s } += ", (60 - $m_s - $s_s/60.0), "\n" if ($DEBUG);
					$exported_tasks->{ $date_s }->{ $h_s } += (60 - $m_s - $s_s/60.0);
					map {
						print "exported_tasks->{ $date_s }->{ $_ } += 60 (until midnight)\n" if ($DEBUG);
						$exported_tasks->{ $date_s }->{ $_ } += 60;
					} ( ($h_s+1)..23 );

					#
					# since midnight
					#
					map {
						print "exported_tasks->{ $date_e }->{ $_ } += 60 (since midnight)\n" if ($DEBUG);
						$exported_tasks->{ $date_e }->{ $_ } += 60;
					} ( 0..($h_e-1) );

					print "exported_tasks->{ $date_e }->{ $h_e } += ", ($m_e + $s_e/60.0), "\n" if ($DEBUG);
					$exported_tasks->{ $date_e }->{ $h_e } += ($m_e + $s_e/60.0);
				}
				else {
					if ($h_e > $h_s) {
						print "exported_tasks->{ $date_s }->{ $h_s } += ", (60 - $m_s - $s_s/60.0), "\n" if ($DEBUG);
						$exported_tasks->{ $date_s }->{ $h_s } += (60 - $m_s - $s_s/60.0);
						map {
							print "exported_tasks->{ $date_s }->{ $_ } += 60\n" if ($DEBUG);
							$exported_tasks->{ $date_s }->{ $_ } += 60;
						} ( ($h_s+1)..($h_e-1) );

						print "exported_tasks->{ $date_s }->{ $h_e } += ", ($m_e + $s_e/60.0), "\n" if ($DEBUG);
						$exported_tasks->{ $date_s }->{ $h_e } += ($m_e + $s_e/60.0);
					}
					else {
						print "exported_tasks->{ $date_s }->{ $h_s } += ", ($m_e + $s_e/60.0 - $m_s - $s_s/60.0), "\n" if ($DEBUG);
						$exported_tasks->{ $date_s }->{ $h_s } += ($m_e + $s_e/60.0 - $m_s - $s_s/60.0);
					}
				}

				my $duration = $dt_e - $dt_s;
				my $dur_mins = $duration->delta_minutes();
				my $dur_secs = $duration->delta_seconds();
				if ($dur_secs > 15 and $dur_mins <= 15) { # short duration round to whole minute up
					$dur_mins += 1;
				}
				$total_minutes_spend += $dur_mins;
				#print Dumper($duration);
				#print $dt_s->strftime('%Y-%m-%d'), " - $dur_mins mins - ", join(' / ', @$path), "\n";
				#print "\t* ", ($ee->{description}->{content} ||''), "\n";
				my $t = $dt_s->strftime('%Y-%m-%d');
				my $p = join(' / ', @$path);
				$exported_tasks->{$t}->{$p}->{duration} ||= 0;
				$exported_tasks->{$t}->{$p}->{duration} +=  $dur_mins;
				#print "$ee->{start} - $ee->{stop}";
			}
			#@ print $prefix, "* ", ($ee->{description}->{content} ||''), "\n";
		}
	}

	foreach my $tt (@{$t->{task}}) {
		$total_minutes_spend += stat_task($tt, $exported_tasks, $subject, [ @$path, $tt->{subject} ], $start_time, $end_time);
	}

	return $total_minutes_spend;

} # }}}


1;

__END__

=head1 NAME

TaskCoach - <<<description of module>>>

=head1 SYNOPSIS

  use TaskCoach;

  my $xxx = new TaskCoach;

=head1 DESCRIPTION

The TaskCoach module allows you ...
<<<your description here>>>

=head2 EXPORT

<<here describe exported methods>>>

=head1 SEE ALSO

=head1 AUTHORS

Lubomir Host 'rajo', <rajo AT platon.sk>

=cut

# vim: ts=4
# vim600: fdm=marker fdl=0 fdc=3

