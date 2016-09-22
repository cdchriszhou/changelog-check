#!/usr/bin/perl
#===============================================================================
#
#         FILE:  build.pl
#
#        USAGE:  ./build.pl
#
#  DESCRIPTION:  DPS2 build script.
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Chris zhou (ty), ytang@ecwise.com
#      COMPANY:  EC|Wise
#      VERSION:  0.0.1
#      CREATED:  2011-05-18
#     REVISION:  ---
#===============================================================================

use lib "lib";
use SVN::Log;
use Log::Log4perl qw(:easy);
use Config::Abstract::Ini;
use Cwd;
use File::Basename;
use File::Spec;
use File::Path;
use Data::Dumper;
use strict;
use warnings;

our $CONFIG = {};                                # global reference

# main process
main();

# ---------------------------------------------------------------------------
sub main {

    # try
    eval {
        # init
        init();

        # start check svn log
        INFO '#' x 10 . 'Start of checking svn logs...' . '#' x 10;

        # get all release settings
        $CONFIG = get_config();

        # INFO Dumper $CONFIG;

        # get svn repos
        my $svn_repos = $CONFIG->{'svn'}{'url'};

        INFO "Start of writing output files...";
        open my $stdout, ">", "dist/" . get_date() . ".STD_JIRA_ChangeLog.csv"
            or die "[ERROR]: Cannot write file: $!";
        open my $errout, ">", "dist/" . get_date() . ".NULL_JIRA_ChangeLog.csv"
            or die "[ERROR]: Cannot write file: $!";
        open my $files_list, ">", "dist/" . get_date() . ".file_list.txt"
            or die "[ERROR]: Cannot write file: $!";

        # print $stdout "MODULE,SP#,FB#,M#,SUMMARY,AUTHOR,DATE,REV,FILES\n";
        # print $errout "MODULE,SP#,FB#,M#,SUMMARY,AUTHOR,DATE,REV,FILES\n";
        
        print $stdout "MODULE,SP#,FB#,CLN#,SUMMARY,AUTHOR,DATE,REV,PATH,DB_PATCH_PATH,FILES\n";
        print $errout "MODULE,SP#,FB#,CLN#,SUMMARY,AUTHOR,DATE,REV,PATH,DB_PATCH_PATH,FILES\n";

        while (my ( $key, $value ) = each %$CONFIG) {
            # ignore svn;
            next if $key eq 'svn';

            INFO "Start of geting svn logs...";
            my $url = $svn_repos . $CONFIG->{$key}{'url'};
            my $start = $CONFIG->{$key}{'start_rev'};
            my $end = $CONFIG->{$key}{'end_rev'};

            INFO "svn -v -r$start:$end $url";
            my $revs = SVN::Log::retrieve ($url, $start, $end);
            INFO "End of geting svn logs!";

            my $module = $key;

            my @all_files;

            foreach my $rev (@$revs) {
                my @files = keys %{$rev->{'paths'}};
                # ignore dps 3
                # next if @files ~~ /\/dps\/Platform\/trunk\/midtier/;
                # ignore fullbuild, tags
                # next if @files ~~ /(full_build)|(tags)/ and !(@files ~~ /patch/);

                my $num = $rev->{'revision'};
                my $date = $rev->{'date'};
                my $author = $rev->{'author'};
                my $message = $rev->{'message'};

                # files with "\n"
                my @newfiles = ();
                #push @newfiles, $_ . "\n" foreach @files;

                my $status = {
                    'D' => 'Deleted',
                    'M' => 'Modified',
                    'A' => 'Added',
                    'R' => 'Replacing',
                };

                my $commit_path = "";
				my $db_patch_path = "";
				my @db_patch_path = "";
				
				
                foreach my $file (@files) {
                    my $action = $rev->{'paths'}{${file}}{'action'};
                    #print $action;
                    push @newfiles, $status->{$action} . ": " . $file . "\n";
                    
                    if ($file =~ /trunk/) {
                        $commit_path = "trunk";
                        
                        if($file =~ /(DB\/DPS2\/patch\/\w+)/) {
                        	
                        	@db_patch_path = split( /DB\/DPS2\/patch\//, $file );
                        	$db_patch_path = $db_patch_path[1];
                        	
                        	@db_patch_path = split( /\//, $db_patch_path );
                        	$db_patch_path= $db_patch_path[0]."/".$db_patch_path[1];
                        } ;
                        
                    } elsif ($file =~ /(branches\/\w+)/) {
                        $commit_path = $1;    
                    } else {
                        $commit_path = "Error Path";
                    }
                }

                # get issues
                my @sp_num = get_sp($message);
                my @fb_num = get_fb($message);
                # my @mantis_num = get_mantis($message);

                # escape character
                $message =~ s/\"/\"\"/g;
                
                if ( $sp_num[0] eq 'None' and $fb_num[0] eq 'None') {
                    print $errout "$module,@sp_num,@fb_num,\"$message\",$author,$date,$num,$commit_path,$db_patch_path,\"@newfiles\"\n";
                } else {
                    print $stdout "$module,@sp_num,@fb_num,\"$message\",$author,$date,$num,$commit_path,$db_patch_path,\"@newfiles\"\n";
                }
                
                # write list files
                push @all_files, @files;
            }

            # print sorted and uniqued files list
            undef my %all;
            my @out = grep !$all{$_}++, @all_files;
            print $files_list join("\n", sort @out);
        }

        INFO "End of writing output files...";
        close $stdout;
        close $errout;
        close $files_list;

        INFO '#' x 10 . 'End of checking svn logs!' . '#' x 10;
    };

    # catch
    if ($@) {
        die "$@\n";
    }    # -----  end eval  -----
}    # ----------  end subroutine  ----------

# ---------------------------------------------------------------------------
sub init {
    # get file name
    my $cur_dir  = getcwd;
    my $log_dir  = File::Spec->catdir( $cur_dir, get_log_dir()  );
    my $log_name = get_date() . '.checklist.log';
    my $log_file = File::Spec->catfile( $log_dir, $log_name );

    # make_path $log_dir or warn "Cannot make dir: $log_dir";

    my $level = $INFO;               # $INFO defined in Log::Log4Perl
    Log::Log4perl->easy_init(
        {
            level => $level,
            file => "STDOUT",
            layout => "%m%n"
        }
        {
            level => $level,
            file => ">> $log_file",
            layout => "%d %p> %F{1}:%L\t- %m%n"
        }
    );
}    # ----------  end subroutine  ----------

# ---------------------------------------------------------------------------
sub get_log_dir {
    return 'logs';
}    # ----------  end subroutine  ----------

# ---------------------------------------------------------------------------
sub get_date {
    my $year  = (localtime)[5] + 1900;
    my $month = (localtime)[4] + 1;
    my $day   = (localtime)[3];

    return $year . '-' . $month . '-' . $day;
}    # ----------  end subroutine  ----------

#---------------------------------------------------------------------------
sub get_config {
    my $cfg_file = 'checklist_config.ini';
    my $cfg = new Config::Abstract::Ini( $cfg_file );

    # Get all settings
    my %all_settings = $cfg->get_all_settings;

    return \%all_settings;
}

# ---------------------------------------------------------------------------
sub get_sp {
    my $msg = shift or return "";
    my @sps=();

    push @sps, $_ foreach $msg =~ /sp[\w|\s|:\#\.]{0,3}?(\d+)/ig;

    push @sps, 'None' if scalar @sps == 0;

    return @sps;
}    # ----------  end subroutine  ----------

sub get_jira {
    my $msg = shift or return "";
    my @sps=();

    push @sps, $_ foreach $msg =~ /cln[\w|\s|:\#\.]{0,3}?(\d+)/ig;

    push @sps, 'None' if scalar @sps == 0;

    return @sps;
}    # ----------  end subroutine  ----------
# ---------------------------------------------------------------------------
sub get_fb {
    my $msg = shift or return "";
    my @fbs=();

    push @fbs, $_ foreach $msg =~ /fb[\w|\s|:\#\.]{0,3}?(\d+)/ig;
    push @fbs, $_ foreach $msg =~ /fogbugz[\w|\s|:\#]{0,3}?(\d+)/ig;

    push @fbs, 'None' if scalar @fbs == 0;

    return @fbs;
}    # ----------  end subroutine  ----------

# ---------------------------------------------------------------------------
