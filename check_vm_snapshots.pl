#!/usr/bin/perl

use strict;
use warnings;

# use common::sense;
use Getopt::Long;
use IPC::System::Simple qw(
    capture capturex system systemx run runx $EXITVAL EXIT_ANY
  );

GetOptions (
	"vm=s" => \my $vm_name,
	"username=s" => \my $username,
	"password=s" => \my $password,
	"vcserver=s" => \my $vc_server,
	"warning=i" => \my $warning,
	"critical=i" => \my $critical,
	"performance" => \my $performance,
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}

sub vcenter_find {	
	# $vm_name =~ /srv([\w]{2,3})[.]*/i;
	if ($_[0] =~ /sb/i){
		return "SRVSBVC01.sanbenedetto.local";
	} elsif ($_[0] =~ /pa/i){
		return "SRVPAVC01.sanbenedetto.local";
	} elsif ($_[0] =~ /ag/i){
		return "SRVAGVC01.sanbenedetto.local";
	} elsif ($_[0] =~ /gg/i){
		return "SRVGGVC01.sanbenedetto.local";
	} elsif ($_[0] =~ /an/i){
		return "SRVANVC01.sanbenedetto.local";
	} elsif ($_[0] =~ /fp/i || $1 =~ /fc/i){
		return "SRVFPVC01.sanbenedetto.local";
	} else {
		print "WARNING: VM Location not recognized\n";
		exit(1);
	}
}

Error('Option --vm required') unless $vm_name;
Error('Option --username required') unless $username;
Error('Option --password required') unless $password;

$vm_name =~ /([\w]{2,3})_(.*)/;
my $sede = $1;
$vm_name = $2;

$vc_server = vcenter_find($sede) unless $vc_server;
my $old_vm_name = $vm_name;
$vm_name = uc($vm_name);
my $output;
eval {
	$output = capture("perl plugins/calaSnapshotSizeForVM.pl --vm $vm_name --username $username --password $password --server $vc_server");
};
if ($@) {
	eval {
		$output = capture("perl plugins/calaSnapshotSizeForVM.pl --vm $old_vm_name --username $username --password $password --server $vc_server");
	};
	if ($@) {
		eval {
			$output = capture("perl plugins/calaSnapshotSizeForVM.pl --vm ".lc($old_vm_name)." --username $username --password $password --server $vc_server");
		};
		if ($@) {
			eval {
				$output = capture("perl plugins/calaSnapshotSizeForVM.pl --vm ".ucfirst(lc($old_vm_name))." --username $username --password $password --server $vc_server");
			};
			if ($@) {
					print "UNKNOWN: Something went wrong - $@\n";
					exit(3);
			}
		}
	}
}

$output =~ s/(.*)\n/$1/;

$output =~ /\(MB\): ([\d]*)/;
if ($1 > $critical){
	print "CRITICAL: $output";
	if ($performance){
		print " | \"snap_size\"=$1;$warning;$critical";
	}
	print "\n";
	exit(2);
} elsif ($1 > $warning) {
	print "WARNING: $output";
	if ($performance){
		print " | \"snap_size\"=$1;$warning;$critical";
	}
	print "\n";
	exit(1);
} else {
	print "OK: $output";
	if ($performance){
		print " | \"snap_size\"=$1;$warning;$critical";
	}
	print "\n";
	exit(0);
}