#!/usr/bin/perl

use strict;

use common::sense;
use Getopt::Long;
use IPC::System::Simple qw(
    capture capturex system systemx run runx $EXITVAL EXIT_ANY
  );

GetOptions (
	"vm=s" => \my $vm_name,
	"username=s" => \my $username,
	"password=s" => \my $password,
	"vcserver=s" => \my $vc_server,
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . $_[0] . "\n";
    exit 2;
}

sub vcenter_find {
	# $vm_name =~ /srv([\w]{2,3})[.]*/i;
	if ($_[0]){
		if ($_[0] =~ /sbs/i){
			return "SRVSBVC01.sanbenedetto.local";
		} elsif ($_[0] =~ /sbp/i){
			return "SRVPAVC01.sanbenedetto.local";
		} elsif ($_[0] =~ /ag/i){
			return "SRVAGVC01.sanbenedetto.local";
		} elsif ($_[0] =~ /gg/i){
			return "SRVGGVC01.sanbenedetto.local";
		} elsif ($_[0] =~ /an/i){
			return "SRVANVC01.sanbenedetto.local";
		} elsif ($_[0] =~ /fp/i || $_[0] =~ /fc/i){
			return "SRVFPVC01.sanbenedetto.local";
		} else {
			print "WARNING: VM Location not recognized\n";
			exit(1);
		}
	} else {
		$vm_name =~ /srv([\w]{2,3})[.]*/i;
		if ($1=~ /sb/i){
			return "SRVSBVC01.sanbenedetto.local";
		} elsif ($1 =~ /pa/i){
			return "SRVPAVC01.sanbenedetto.local";
		} elsif ($1 =~ /ag/i){
			return "SRVAGVC01.sanbenedetto.local";
		} elsif ($1 =~ /gg/i){
			return "SRVGGVC01.sanbenedetto.local";
		} elsif ($1 =~ /an/i){
			return "SRVANVC01.sanbenedetto.local";
		} elsif ($1 =~ /fp/i || $1 =~ /fc/i){
			return "SRVFPVC01.sanbenedetto.local";
		} else {
			print "WARNING: VM Location not recognized\n";
			exit(1);
		}
	}
}

Error('Option --vm required') unless $vm_name;
Error('Option --username required') unless $username;
Error('Option --password required') unless $password;

my $sede;
if ($vm_name =~ /([\w]{2,3})_(.*)/) {
	$sede = $1;
	$vm_name = $2;
}

$vc_server = vcenter_find($sede) unless $vc_server;
my $old_vm_name = $vm_name;
$vm_name = uc($vm_name);
my $output;
eval {
	$output = capture("perl plugins/vminfo.pl --vmname $vm_name --username $username --password $password --server $vc_server --fields overallStatus");
};
if ($@) {
	eval {
		$output = capture("perl plugins/vminfo.pl --vmname $old_vm_name --username $username --password $password --server $vc_server --fields overallStatus");
	};
	if ($@) {
		eval {
			$output = capture("perl plugins/vminfo.pl --vmname ".lc($old_vm_name)." --username $username --password $password --server $vc_server --fields overallStatus");
		};
		if ($@) {
			eval {
				$output = capture("perl plugins/vminfo.pl --vmname ".ucfirst(lc($old_vm_name))." --username $username --password $password --server $vc_server --fields overallStatus");
			};
			if ($@) {
					print "UNKNOWN: Something went wrong - $@\n";
					exit(3);
			}
		}
	}
}

$output =~ /(.*):[\s]+The entity (.*)/;

if ($2 =~ /is OK/){
	print "OK: Overall status is OK\n";
	exit(0);
} elsif ($2 =~ /might have/) {
	print "WARNING: Overall status is not OK\n";
	exit(1);
} elsif ($output =~ /Virtual Machine (.*) not found./){
	print "UNKNOWN: Virtual machine not found\n";
	exit(3);
}
