#!/usr/bin/perl -w
############################################################################################################
# - author: Jin Rong Zhao
# - date: 2016/09/05
# - comments: this script is used to generate the total snapshots' size for the specified single VM.
# - usage: to invoke the method as below
#   ./calaSnapshotSizeForVM.pl --vm vm_name --server vc_ip --username account_name --password account_pwd
############################################################################################################

use strict;
use VMware::VIRuntime;
use VMware::VILib;

my %opts = (
        vm => {
        type => "=s",
        help => "The name of virtual machine",
        required => 1
        },

        server => {
        type => "=s",
        help => "The url of the the vCenter Server",
        required => 1
        },

        username => {
        type => "=s",
        help => "The name of the account to login the vCenter Server",
        required => 1
        },

        password => {
        type => "=s",
        help => "The password of the account to login the vCenter Server",
        required => 1
        }
);

&calc_snapshot_size();

sub calc_snapshot_size {
	
	# 1.Connect VC
	Opts::add_options(%opts);
	Opts::parse();
	Opts::validate();
	Util::connect();

	# 2.Get vm with certain properties
	my $vm = Opts::get_option('vm');
	my $vm_views = Vim::find_entity_views(
		view_type  => 'VirtualMachine',
		filter     => { 'name' => $vm },
		properties => [
			'config.files',
			'environmentBrowser'
		]
	);
	unless(@$vm_views|$vm_views){
		print("\$vm $vm not found\n");
		Util::disconnect();
		return;
	}
	my $vm_view = @$vm_views[0];

	# 3.Retrive datastorePath
	my $ds_path = $vm_view->{'config.files'}->snapshotDirectory;
	# print("\$ds_path: $ds_path\n");
	
	my $fqf = FileQueryFlags->new(
		fileSize 		=> 1,
		fileType 		=> 1,
		fileOwner		=> 1,
		modification	=> 1
	);
	
	# 4.Construct searchSpec
	my $searchSpec = HostDatastoreBrowserSearchSpec->new(
		details      			=> $fqf,
		query					=> [VmDiskFileQuery->new(), VmSnapshotFileQuery->new()],
		matchPattern 			=> ["$vm-00000*.vmdk", "$vm-Snapshot*.vmsn"],
		sortFoldersFirst		=> 1,
		searchCaseInsensitive	=> 0,
	);
	
	# 5.Call related SerachMethod with params provided by step 3 & 4
	my $envBrowser = Vim::get_view(mo_ref => $vm_view->{'environmentBrowser'});
	my $datastoreBrowser = Vim::get_view(mo_ref => $envBrowser->{'datastoreBrowser'});
	my $task_ref = $datastoreBrowser->SearchDatastoreSubFolders_Task(
		datastorePath 	=> $ds_path,
		searchSpec  	=> $searchSpec
	);
	sleep 1;
	my $task_status = Vim::get_view(mo_ref => $task_ref)->info->state->val;
	my $snapshot_number = 0;
	# print("task status: $task_status\n");
	if($task_status eq 'success'){	
		#returnType: HostDatastoreBrowserSearchResults[]
		my $task_results = Vim::get_view(mo_ref => $task_ref)->info->result;
		my $snapshot_size_total = 0.0;
		foreach my $res(@$task_results){
			my $class = ref $res;
			if ($class->isa('HostDatastoreBrowserSearchResults')){
				my $res_files = $res->file;
				foreach my $file(@$res_files){
					#Display related fileName with fileSize
					my $file_size_kb = sprintf("%.2f", $file->fileSize/(1024));
					$snapshot_size_total += $file_size_kb;
					$snapshot_number += 1;
				    # print("fileName: ".$file->path.", fileSize(KB): ".$file_size_kb."\n")
				}
			}
		}
		print("# Snapshots: $snapshot_number; Total snapshot size(MB): ".sprintf("%.2f", $snapshot_size_total/(1024))."\n")
	}elsif($task_status eq 'error'){
		my $error_msg = Vim::get_view(mo_ref => $task_ref)->info->error->localizedMessage;
		print("executing search task meet error: $error_msg\n");
	}
	
	# 6.Disconnect VC
	Util::disconnect();
}

1;
