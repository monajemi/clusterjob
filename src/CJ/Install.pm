package CJ::Install;
# This class takes care of Installation
# Copyright 2017 Hatef Monajemi (monajemi@stanford.edu)

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use Data::Dumper;
use feature 'say';



####################
# class constructor
sub new {
####################
 	my $class= shift;
    my ($app,$machine,$path) = @_;
    
    $path //= "CJinstalled";  #SOME_DEFAULT # This path relative to ~/
    
    my $self = bless {
        app  => $app,
        machine => $machine,
        path => $path
    }, $class;
    return $self;
}




################
sub anaconda{
    my $self = shift;
    
    
my $anaconda = "Anaconda3-4.4.0-Linux-x86_64";
my $distro  = "https://repo.continuum.io/archive/${anaconda}.sh";
my $installpath = "\$HOME/$self->{path}/anaconda";
    
    
# -------------------
my $install_bash_script  =<<'BASH';
    
#module load anaconda

if [ -n "$(which conda)" ]; then
    
    echo "Anaconda is already installed in $(which conda)";
    exit 0;

else
    START=`date +%s`

    echo "GETTING anaconda from <DISTRO>";
    if [ -f <ANACONDA>.sh ]; then rm -f <ANACONDA>.sh; fi;
    wget "<DISTRO>"
    
    echo "INSTALLING anaconda";
    if [ -d <INSTALLPATH> ]; then
    printf "ERROR: directory <INSTALLPATH> exists. Aborting install. \
        \nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
        exit 1;
    fi
    
    bash <ANACONDA>.sh -b -p <INSTALLPATH>;

    rm <ANACONDA>.sh
    echo 'export PATH="<INSTALLPATH>/bin:$PATH" ' >> $HOME/.bashrc
    source $HOME/.bashrc
    yes | conda update conda

    if [ $? -eq 0 ]; then
        END=`date +%s`;
        RUNTIME=$((END-START));
        echo "INSTALL SUCCESSFUL ($RUNTIME seconds)"
        exit 0;
    else
        echo "****INSTALL FAILED*****";
        exit 1;
    fi
    
fi


    
    
    
    
BASH
    
$install_bash_script =~ s|<DISTRO>|$distro|g;
$install_bash_script =~ s|<ANACONDA>|$anaconda|g;
$install_bash_script =~ s|<INSTALLPATH>|$installpath|g;
# -----------------

    
my $ssh = CJ::host($self->{'machine'});

my $filename = "CJ_install_anaconda.sh";
my $filepath = "/tmp/$filename";
&CJ::writeFile($filepath, $install_bash_script);
my $cmd = "scp $filepath $ssh->{account}:.";
&CJ::my_system($cmd,0);

    
&CJ::message("----- START BASH ON $self->{'machine'}-----",1);
$cmd = "ssh $ssh->{account} 'bash -l \$HOME/CJ_install_anaconda.sh 2>/dev/null' ";
system($cmd);

$cmd = "ssh $ssh->{account} 'if [ -d \$HOME/$self->{path} ] ; then mv \$HOME/CJ_install_anaconda.sh \$HOME/$self->{path}/; fi' ";
system($cmd);

    
&CJ::message("----- END BASH ON $self->{'machine'}-----",1);
   
    
    
    
    
    
    
exit 0;
   
    # from commit
    # 8ced93afebb9aaee12689d3aff473c9f02bb9d78
    # we are moving to anaconda virtual env
    # for python

    #    then
        #
    #    # IMPROVE: There must be a check here using $?.
    #    # in case installation fails
    #
    #
    #    #  If the venv already exists, just use it!
    #    #  For parallel package, this prevents buiding venv
    #    #  for each job!
    #
    #    if [[ -z $( conda info --envs | grep python_venv_\$PID ) ]]; then
    #    echo "python_venv_\$PID  doesn't exist. Creating it..."
    #    conda create --yes -n python_venv_\$PID python=$python_version_tag anaconda
    #    else
    #        echo "using python_venv_\$PID"
    #        fi
    #        
    #    
    #}
    
    
}



















1;
