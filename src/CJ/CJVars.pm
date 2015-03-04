package CJ::CJVars;
# This is part of Clusterjob 
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

use strict;
use warnings;
use parent 'Exporter'; # imports and subclasses Exporter
use FILE::Basename qw(dirname);



my  $CJ_dir = File::Basename::dirname(__FILE__);
my  @CJ_dir_array = split '/',$CJ_dir;
my  $lastone = pop @CJ_dir_array;
our $install_dir  = join '/', @CJ_dir_array;


our $HOME            = $ENV{"HOME"};
our $remotePrefix    = "~/RunRepo_remote/";
our $localPrefix     = "$HOME/RunRepo_local/";
our $savePrefix      = "$HOME/Dropbox/clusterjob_saveRepo/";

our $last_instance_file = "$install_dir/.info/last_instance.info";
our $last_instance_result_dir = "$install_dir/last_instance_results";
our $history_file       = "$install_dir/.info/history.info";
our $run_history_file   = "$install_dir/.info/run_history.info";
our $save_info_file     = "$install_dir/.info/save.info";



# Export global variables
our @EXPORT = qw($install_dir $remotePrefix $localPrefix $savePrefix $last_instance_file $last_instance_result_dir $history_file $run_history_file $save_info_file);




1;