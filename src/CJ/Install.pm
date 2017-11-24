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






sub miniconda{

my $self = shift;
my ($force_tag) = @_;

    
my $miniconda = "Miniconda3-latest-Linux-x86_64";
my $distro  = "https://repo.continuum.io/miniconda/${miniconda}.sh";
my $installpath = "\$HOME/$self->{path}/miniconda";
    

# -------------------
my $install_bash_script  =<<'BASH';
#!/bin/bash -l

#module load anaconda

if [ -n "$(which conda)" ]; then
echo "conda is already installed in $(which conda)";
exit 0;

else
    START=`date +%s`
    
    echo "GETTING miniconda from <DISTRO>";
    if [ -f <MINICONDA>.sh ]; then rm -f <MINICONDA>.sh; fi;
    wget "<DISTRO>"

    echo "INSTALLING Miniconda";
    if [ -d <INSTALLPATH> ]; then
    printf "ERROR: directory <INSTALLPATH> exists. Aborting install. \
    \nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
    exit 1;
    fi

    bash <MINICONDA>.sh -b -p <INSTALLPATH>;

    rm <MINICONDA>.sh
    echo 'export PATH="<INSTALLPATH>/bin:$PATH" ' >> $HOME/.bashrc
    echo 'export PATH="<INSTALLPATH>/bin:$PATH" ' >> $HOME/.bash_profile

    
    if [ -f "$HOME/.bashrc" ]; then source $HOME/.bashrc; fi
    if [ -f "$HOME/.bash_profile" ] ; then source $HOME/.bash_profile; fi
    
    conda update --yes conda

    if [ $? -eq 0 ]; then
    END=`date +%s`;
    RUNTIME=$((END-START));
    echo "INSTALL SUCCESSFUL ($RUNTIME seconds)"
    exit 0;
    else
    echo "****INSTALL FAILED***** $? "
    exit 1
    fi

fi
    
BASH

$install_bash_script =~ s|<DISTRO>|$distro|g;
$install_bash_script =~ s|<MINICONDA>|$miniconda|g;
$install_bash_script =~ s|<INSTALLPATH>|$installpath|g;
# -----------------


my $ssh = CJ::host($self->{'machine'});

    
# if forced clear the previous installation if any
if($force_tag == 1){
    &CJ::message("(forced) removing prior installation of miniconda in $installpath");
    my $cmd = "ssh $ssh->{account} 'rm -rf $installpath' ";
    &CJ::my_system($cmd,0);
}
    
    
    
    
my $filename = "CJ_install_miniconda.sh";
my $filepath = "/tmp/$filename";
&CJ::writeFile($filepath, $install_bash_script);
my $cmd = "scp $filepath $ssh->{account}:.";
&CJ::my_system($cmd,0);


&CJ::message("----- START BASH ON $self->{'machine'}-----",1);
$cmd = "ssh $ssh->{account} 'cd \$HOME && bash -l CJ_install_miniconda.sh' ";
system($cmd);

$cmd = "ssh $ssh->{account} 'if [ -d \$HOME/$self->{path} ] ; then mv \$HOME/CJ_install_miniconda.sh \$HOME/$self->{path}/; fi' ";
system($cmd);


&CJ::message("----- END BASH ON $self->{'machine'}-----",1);
    
    return 1;
}




################
sub anaconda{
    my $self = shift;
    my ($force_tag) = @_;

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

    
    
# if forced clear the previous installation if any
    if($force_tag == 1){
        &CJ::message("(forced) removing prior installation of anaconda in $installpath");
        my $cmd = "ssh $ssh->{account} 'rm -rf $installpath' ";
        &CJ::my_system($cmd,0);
    }
    
    
    
    
my $filename = "CJ_install_anaconda.sh";
my $filepath = "/tmp/$filename";
&CJ::writeFile($filepath, $install_bash_script);
my $cmd = "scp $filepath $ssh->{account}:.";
&CJ::my_system($cmd,0);

    
&CJ::message("----- START BASH ON $self->{'machine'}-----",1);
$cmd = "ssh $ssh->{account} 'cd \$HOME && bash -l CJ_install_anaconda.sh' ";
system($cmd);

$cmd = "ssh $ssh->{account} 'if [ -d \$HOME/$self->{path} ] ; then mv \$HOME/CJ_install_anaconda.sh \$HOME/$self->{path}/; fi' ";
system($cmd);

    
&CJ::message("----- END BASH ON $self->{'machine'}-----",1);
   
    return 1;
}



###################
sub cvx {
###################
    
    my $self = shift;
    my ($force_tag) = @_;

my $cvx = "cvx-rd";
my $distro  = "http://web.cvxr.com/cvx/${cvx}.tar.gz";
my $installpath = "\$HOME/$self->{path}";

    
# -------------------
my $install_bash_script  =<<'BASH';
    
START=`date +%s`

echo "GETTING CVX from <DISTRO>";
if [ -f <CVX>.tar.gz ]; then rm -f <CVX>.tar.gz; fi;
wget "<DISTRO>"

echo "INSTALLING in <INSTALLPATH>/cvx";
if [ -d "<INSTALLPATH>/cvx" ]; then
printf "ERROR: directory <INSTALLPATH>/cvx exists. Aborting install. \
\nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
exit 1;
fi

if [ ! -d  "<INSTALLPATH>"  ] ; then
    mkdir <INSTALLPATH> ;
fi
    
cp <CVX>.tar.gz <INSTALLPATH>/.
cd <INSTALLPATH>
tar -xzvf <CVX>.tar.gz
rm -f <CVX>.tar.gz

    END=`date +%s`;
    RUNTIME=$((END-START));
    echo "INSTALL SUCCESSFUL ($RUNTIME seconds)"
    exit 0;
    
BASH
    
$install_bash_script =~ s|<DISTRO>|$distro|g;
$install_bash_script =~ s|<CVX>|$cvx|g;
$install_bash_script =~ s|<INSTALLPATH>|$installpath|g;
# -----------------
    
    
my $ssh = CJ::host($self->{'machine'});
    
    

# if forced clear the previous installation if any
if($force_tag == 1){
    &CJ::message("(forced) removing prior installation of cvx in $installpath");
    my $cmd = "ssh $ssh->{account} 'rm -rf $installpath' ";
    &CJ::my_system($cmd,0);
}
    
    
   
    
my $filename = "CJ_install_cvx.sh";
my $filepath = "/tmp/$filename";
&CJ::writeFile($filepath, $install_bash_script);
my $cmd = "scp $filepath $ssh->{account}:.";
&CJ::my_system($cmd,0);


&CJ::message("----- START BASH ON $self->{'machine'}-----",1);
$cmd = "ssh $ssh->{account} 'cd \$HOME && bash -l CJ_install_cvx.sh' ";
system($cmd);

$cmd = "ssh $ssh->{account} 'if [ -d \$HOME/$self->{path} ] ; then mv \$HOME/CJ_install_cvx.sh \$HOME/$self->{path}/; fi' ";
system($cmd);


&CJ::message("----- END BASH ON $self->{'machine'}-----",1);

return 1;
}

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    














1;
