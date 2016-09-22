#!/usr/bin/perl
#===============================================================================
#
#         FILE:  svn_log_init.pl
#
#        USAGE:  perl svn_log_init.pl
#
#  DESCRIPTION:  Trialogue SVN Information INIT
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:
#      COMPANY:  EC|Wise
#      VERSION:  0.0.1
#      CREATED:
#     REVISION:  ---
#===============================================================================

use lib "lib";
use SVN::Log;
use File::Path qw(make_path remove_tree);
use Log::Log4perl qw(:easy);
use Config::Abstract::Ini;
use Cwd;
use strict;
use warnings;

our $CONFIG = {};    # global reference

# main process
main();

sub main {
	log_init();

	# get all release settings
	$CONFIG = get_config();

	# get svn repos
	my $svn_repos      = $CONFIG->{'svn'}{'url'};
	my $cur_date       = getdate();
	my $cur_date_ymdhm = $cur_date->{ymdhm};
	open my $export_config, ">", "export/" . $cur_date_ymdhm . ".config.ini"
	  or die "[ERROR]: Cannot write file: $!";

	#print $export_config "[svn]\nurl=https://svn.ecwise.com/svn\n\n";
	print $export_config "[svn]\nurl=https://vcs2.regulusgroup.net/svn/t2\n\n";
	while ( my ( $module, $value ) = each %$CONFIG ) {

		# ignore svn;
		next if $module eq 'svn';

		my $url = $svn_repos . $CONFIG->{$module}{'url'};

		my $start_rev = $CONFIG->{'svn'}{'start_rev'};
		my $end_rev   = 'HEAD';
		my $revs      = SVN::Log::retrieve( $url, $start_rev, $end_rev );

		my @new_revs;
		my $new_rev_1 = '';
		my $new_rev_2 = '';

		foreach my $rev (@$revs) {
			my @files = keys %{ $rev->{'paths'} };

			my $revision = $rev->{'revision'};
			my $date     = $rev->{'date'};
			my $author   = $rev->{'author'};
			my $message  = $rev->{'message'};

			foreach my $file (@files) {
				my $action = $rev->{'paths'}{ ${file} }{'action'};
				if (    $file =~ /tags/
					and uc $action eq 'A'
					and $file =~ /RC[0-9]/
					#and $file =~ /\d\.\d\.\d$/ 
					)
				{
					push( @new_revs, $revision );
				}
			}
		}

		@new_revs = sort { $a <=> $b } @new_revs;
		$new_rev_1 = pop(@new_revs);
		$new_rev_2 = pop(@new_revs);
		INFO "The lastest Tag revision of $module is: $new_rev_1 ***** The Second Tag revision of $module is: $new_rev_2 ";
		my $module_url = $CONFIG->{$module}{'url'};
		print $export_config
		  "[$module]\nurl=$module_url\nstart_rev=$new_rev_1\nend_rev=HEAD\n\n";
	}

	close $export_config;
}

sub get_config {
	my $cfg_file = 'svn_config.ini';
	my $cfg      = new Config::Abstract::Ini($cfg_file);

	# Get all settings
	my $all_settings = $cfg->get_all_settings;

	return $all_settings;
}

sub getdate {
	my $time = time();

	my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
	  localtime($time);

	$mon++;
	$sec  = ( $sec < 10 )  ? "0$sec"  : $sec;
	$min  = ( $min < 10 )  ? "0$min"  : $min;
	$hour = ( $hour < 10 ) ? "0$hour" : $hour;
	$mday = ( $mday < 10 ) ? "0$mday" : $mday;
	$mon = ( $mon < 10 ) ? "0" . ($mon) : $mon;
	$year += 1900;

	my $weekday = ( 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' )[$wday];
	return {
		'second' => $sec,
		'minute' => $min,
		'hour'   => $hour,
		'day'    => $mday,
		'month'  => $mon,
		'year'   => $year,
		'ymdhm'  => "$year$mon$mday$hour$min",
		'ym'     => "$year$mon",
		'ymd'    => "$year$mon$mday"
	};
}

sub log_init {

	# get file name
	my $cur_dir        = getcwd;
	my $cur_date       = getdate();
	my $cur_date_ymdhm = $cur_date->{ymdhm};
	my $log_dir        = File::Spec->catdir( $cur_dir, 'logs' );
	my $log_name       = $cur_date_ymdhm . '-confing-init.log';
	my $log_file       = File::Spec->catfile( $log_dir, $log_name );

	make_path $log_dir;

	my $level = $INFO;    # $INFO defined in Log::Log4Perl
	Log::Log4perl->easy_init(
		{
			level  => $level,
			file   => "STDOUT",
			layout => "%m%n"
		},
		{
			level  => $level,
			file   => ">> $log_file",
			layout => "%d %p> %F{1}:%L - %m%n"
		}
	);
}
