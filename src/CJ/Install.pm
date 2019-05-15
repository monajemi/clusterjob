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







sub __apply_install{
    
    my $self=shift;
    my ($force_tag, $installpath, $install_bash_script, $background) = @_;
    $background ||= 0;
    
    my $ssh = CJ::host($self->{'machine'});
    
    # if forced clear the previous installation if any
    if($force_tag == 1){
        &CJ::message("(forced) removing prior installation of $self->{app} in $installpath");
        my $cmd = "ssh $ssh->{account} 'rm -rf $installpath' ";
        &CJ::my_system($cmd,0);
    }
    
    
    
    
    my $filename = "CJ_install_". $self->{app} . ".sh";
    my $filepath = "/tmp/$filename";
    &CJ::writeFile($filepath, $install_bash_script);
    my $cmd = "scp $filepath $ssh->{account}:.";
    &CJ::my_system($cmd,1);
    
    &CJ::message("----- START BASH ON $self->{'machine'}-----",1);
    if($background){
        $cmd = "ssh $ssh->{account} 'cd \$HOME && nohup bash -l $filename &>/dev/null &' ";
    }else{
        $cmd = "ssh $ssh->{account} 'cd \$HOME && bash -l $filename' ";
    }
    system($cmd);
    
    $cmd = "ssh $ssh->{account} 'if [ -d \$HOME/$self->{path} ] ; then mv \$HOME/$filename \$HOME/$self->{path}/; fi' ";
    system($cmd);
    
    &CJ::message("----- END BASH ON $self->{'machine'}-----",1);
    
}


sub __local_lib{
        my $self = shift;
my $install_bash_script  =<<'BASH';
    wget http://search.cpan.org/CPAN/authors/id/A/AP/APEIRON/local-lib-1.005001.tar.gz
    tar zxf local-lib-1.005001.tar.gz
    cd ~/local-lib-1.005001
    perl Makefile.PL --bootstrap
    make test && make install
    echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >>~/.bashrc
BASH

    $self->__apply_install(0, "~", $install_bash_script, 1);
}

sub __setup_cj_hub{
    my $self = shift;
my $install_bash_script  =<<'BASH';
    wget http://search.cpan.org/CPAN/authors/id/A/AP/APEIRON/local-lib-1.005001.tar.gz
    tar zxf local-lib-1.005001.tar.gz
    cd ~/local-lib-1.005001
    perl Makefile.PL --bootstrap
    make test && make install
    echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >>~/.bashrc
    PATH="/home/ubuntu/perl5/bin${PATH:+:${PATH}}"; export PATH;
    PERL5LIB="/home/ubuntu/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
    PERL_LOCAL_LIB_ROOT="/home/ubuntu/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
    PERL_MB_OPT="--install_base \"/home/ubuntu/perl5\""; export PERL_MB_OPT;
    PERL_MM_OPT="INSTALL_BASE=/home/ubuntu/perl5"; export PERL_MM_OPT;
    cpan install LWP::UserAgent;
    cpan install Net::SSLeay;
    cpan install IO::Socket::SSL;
    cpan install Net::SSL;
    cpan install LWP::Protocol::https;
    cpan install JSON;

BASH
    $self->__apply_install(0, "~", $install_bash_script, 1);


}


sub __libssl{
    my $self=shift;
    my $ssh = CJ::host($self->{'machine'});
    &CJ::message("Open SSL must be installed for CJ Hub to work",1);
    my $cmd = "ssh $ssh->{account} 'sudo apt-get install libssl-dev'";
    &CJ::my_system($cmd,1);
}




#########
sub java{
    #####
    
    my $self=shift;
    my ($force_tag) = @_;
    
    my $java    = 'jdk-8u171-linux-x64';
    my $distro  ='http://download.oracle.com/otn-pub/java/jdk/8u171-b11/512cd62ec5174c3487ac17c61aaa89e8';
    my $installpath = "\$HOME/$self->{path}/java";
    #-------------------------------------------------------
    
    

    
my $install_bash_script  =<<'BASH';

START=`date +%s`

echo "GETTING <JAVA> from <DISTRO>";
if [ -f <JAVA>.tar.gz ]; then rm -f <JAVA>.tar.gz; fi;
wget --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "<DISTRO>/<JAVA>.tar.gz"


echo "INSTALLING <JAVA>";
if [ -d <INSTALLPATH> ]; then
printf "ERROR: directory <INSTALLPATH> exists. Aborting install. \
\nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
exit 1;
fi

# Go to java home dir, and unzip the source file
if [ ! -d  "<INSTALLPATH>"  ] ; then
mkdir -p <INSTALLPATH> ;
fi


cp <JAVA>.tar.gz <INSTALLPATH>/.
cd <INSTALLPATH>
tar xzvf <JAVA>.tar.gz

JAVA_HOME=<INSTALLPATH>/<JAVA>
    
    
export PATH=$JAVA_HOME:$PATH
echo 'export PATH="$JAVA_HOME:$PATH" ' >> $HOME/.bashrc
echo 'export PATH="$JAVA_HOME:$PATH" ' >> $HOME/.bash_profile


if [ -f "$HOME/.bashrc" ]; then source $HOME/.bashrc; fi
if [ -f "$HOME/.bash_profile" ] ; then source $HOME/.bash_profile; fi


BASH




$install_bash_script =~ s|<DISTRO>|$distro|g;
$install_bash_script =~ s|<JAVA>|$java|g;
$install_bash_script =~ s|<INSTALLPATH>|$installpath|g;


$self->__apply_install($force_tag,$installpath, $install_bash_script);

    return $installpath;
}







###########
sub __curl{
    #######
    my $self=shift;
    my ($force_tag) = @_;
    
    my $curl    = 'curl-7.47.1';
    my $distro  ='https://curl.haxx.se/download';
    my $installpath = "\$HOME/$self->{path}/curl";
    #-------------------------------------------------------
    
    
    
    
    
my $install_bash_script  =<<'BASH';
    
    START=`date +%s`
    
    echo "GETTING curl from <DISTRO>";
    if [ -f <CURL>.tar.gz ]; then rm -f <CURL>.tar.gz; fi;
    wget --no-check-certificate "<DISTRO>/<CURL>.tar.gz"

    
    echo "INSTALLING <CURL>";
    if [ -d <INSTALLPATH> ]; then
    printf "ERROR: directory <INSTALLPATH> exists. Aborting install. \
    \nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
    exit 1;
    fi
    
    # Go to curl home dir, and unzip the source file
    if [ ! -d  "<INSTALLPATH>"  ] ; then
        mkdir -p <INSTALLPATH> ;
    fi

    
    cp <CURL>.tar.gz <INSTALLPATH>/.
    cd <INSTALLPATH>
    tar xzvf <CURL>.tar.gz
    rm -f <CURL>.tar.gz
    cd <CURL>
    ./configure --prefix=<INSTALLPATH>
    make -j3
    make install
    
    
    echo 'export PATH="<INSTALLPATH>/bin:$PATH" ' >> $HOME/.bashrc
    echo 'export PATH="<INSTALLPATH>/bin:$PATH" ' >> $HOME/.bash_profile
    
    
    if [ -f "$HOME/.bashrc" ]; then source $HOME/.bashrc; fi
    if [ -f "$HOME/.bash_profile" ] ; then source $HOME/.bash_profile; fi
    
    
BASH

    
    
    
    $install_bash_script =~ s|<DISTRO>|$distro|g;
    $install_bash_script =~ s|<CURL>|$curl|g;
    $install_bash_script =~ s|<INSTALLPATH>|$installpath|g;
    
    
    $self->__apply_install($force_tag,$installpath, $install_bash_script);
    
    
    
    
    
    
    return $installpath;
}






###########
sub __xz{
    #######
    my $self=shift;
    my ($force_tag) = @_;
    
    my $xz    = 'xz-5.2.2';
    my $distro  ='http://tukaani.org/xz';
    my $installpath = "\$HOME/$self->{path}/xz";
    #-------------------------------------------------------
    

my $install_bash_script  =<<'BASH';

START=`date +%s`

echo "GETTING <XZ> from <DISTRO>";
if [ -f <XZ>.tar.gz ]; then rm -f <XZ>.tar.gz; fi;
wget --no-check-certificate "<DISTRO>/<XZ>.tar.gz"


echo "INSTALLING <XZ>";
if [ -d <INSTALLPATH> ]; then
printf "ERROR: directory <INSTALLPATH> exists. Aborting install. \
\nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
exit 1;
fi

# Go to curl home dir, and unzip the source file
if [ ! -d  "<INSTALLPATH>"  ] ; then
    mkdir -p <INSTALLPATH> ;
fi


cp <XZ>.tar.gz <INSTALLPATH>/.
cd <INSTALLPATH>
tar xzvf <XZ>.tar.gz
rm <XZ>.tar.gz
cd <XZ>
./configure --prefix=<INSTALLPATH>
make -j3
make install


echo 'export PATH="<INSTALLPATH>/bin:$PATH" ' >> $HOME/.bashrc
echo 'export PATH="<INSTALLPATH>/bin:$PATH" ' >> $HOME/.bash_profile


if [ -f "$HOME/.bashrc" ]; then source $HOME/.bashrc; fi
if [ -f "$HOME/.bash_profile" ] ; then source $HOME/.bash_profile; fi


BASH
    
    
    
    
    $install_bash_script =~ s|<DISTRO>|$distro|g;
    $install_bash_script =~ s|<XZ>|$xz|g;
    $install_bash_script =~ s|<INSTALLPATH>|$installpath|g;
    
    
    $self->__apply_install($force_tag,$installpath, $install_bash_script);
    
    return $installpath;
}














###########
sub rstats{
    #######
    
    my $self=shift;
    my ($force_tag) = @_;
    
    
my $R = 'R-3.5.0';
my $distro  ='https://cloud.r-project.org/src/base/R-3';
my $installpath = "\$HOME/$self->{path}/R";
    
# -------------------
my $install_bash_script  =<<'BASH';
#!/bin/bash -l


if [ -n "$(which R)" ]; then
echo "R is already installed in $(which R)";
exit 0;

else
    START=`date +%s`
    
    echo "GETTING R from <DISTRO>";
    if [ -f <R>.tar.gz ]; then rm -f <R>.tar.gz; fi;
    wget "<DISTRO>/<R>.tar.gz"

    echo "INSTALLING R";
    if [ -d <INSTALLPATH> ]; then
        printf "ERROR: directory <INSTALLPATH> exists. Aborting install. \
        \nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
        exit 1;
    fi
    
    # Go to R home dir, and unzip the source file
    if [ ! -d  "<INSTALLPATH>"  ] ; then
        mkdir -p <INSTALLPATH> ;
    fi
    
    cp <R>.tar.gz <INSTALLPATH>/.
    cd <INSTALLPATH>
    tar -xzvf <R>.tar.gz
    rm -f <R>.tar.gz
    
    # configiure and make
    cd <R>
    
    
    ./configure --with-readline=no --with-x=no LDFLAGS="<LDFLAGS>" CPPFLAGS="<CPPFLAGS>"
    
    make
    
   echo 'export PATH="<INSTALLPATH>/<R>/bin:$PATH" ' >> $HOME/.bashrc
   echo 'export PATH="<INSTALLPATH>/<R>/bin:$PATH" ' >> $HOME/.bash_profile


    if [ -f "$HOME/.bashrc" ]; then source $HOME/.bashrc; fi
    if [ -f "$HOME/.bash_profile" ] ; then source $HOME/.bash_profile; fi

    # test that R is installed
    R -e  'print("OK")'

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
    $install_bash_script =~ s|<R>|$R|g;
    $install_bash_script =~ s|<INSTALLPATH>|$installpath|g;

    
    
    
    
    
    # -----------------
    # Install deps for R
    my $curl_path = $self->__curl($force_tag)  ;      # install curl
    my $lzma_path = $self->__xz($force_tag)    ;      # install lzma
    my $java_path = $self->java($force_tag)    ;      # install lzma
    
    
    my $ldflags="-L${curl_path}/lib -L${lzma_path}/lib";
    my $cppflags="-I${curl_path}/include/curl -I${lzma_path}/include";
    $install_bash_script =~ s|<LDFLAGS>|$ldflags|g;
    $install_bash_script =~ s|<CPPFLAGS>|$cppflags|g ;
    
    
    
    #-----------------------------------
    $self->__apply_install($force_tag,$installpath, $install_bash_script);
    
return 1;
    
}





















#############
sub composer{
    #########
    
    my $self = shift;
    my($force_tag) = @_;

my $distro="https://composer.github.io/installer.sig";
my $composer = "composer-setup.php";
my $installer   = "https://getcomposer.org/installer";
my $installpath = "\$HOME/$self->{path}/PHP/composer";
    
# -------------------
my $install_bash_script =<<'BASH';
    
    # INSTALL PHP if not installed
    if [ -n "$(which php)" ] ; then
        sudo apt-get update
        sudo apt-get install php
    fi

    
    if [ -n "$(which composer)" ] ; then
        echo "composer is already installed in $(which composer)";
        exit 0;
    elif [ -n "$(command -v composer)" ] ; then
        echo "composer is already installed in $(command -v composer)";
        exit 0;
    else
        START=`date +%s`
    
        
        echo "GETTING composer from <DISTRO>";
        if [ -f <COMPOSER_SETUP> ]; then rm -f <COMPOSER_SETUP>; fi;
        EXPECTED_SIGNATURE=$(wget -q -O - "<DISTRO>")
    
        echo "INSTALLING composer";
        if [ -d <INSTALLPATH> ]; then
            printf "ERROR: directory <INSTALLPATH> exists. Aborting install. \
            \nYou may use 'cj install -f ...' to remove this directory for a fresh install\n";
            exit 1;
        else
            mkdir -p <INSTALLPATH>
        fi
    
        php -r "copy('<INSTALLER>', '<COMPOSER_SETUP>');"
        ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', '<COMPOSER_SETUP>');")
    
    
        if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ];then
            printf "ERROR: Invalid installer signature"
            rm <COMPOSER_SETUP>
            exit 1
        fi
        
        php composer-setup.php --install-dir=<INSTALLPATH> --filename=composer
        rm <COMPOSER_SETUP>
        echo 'export PATH="<INSTALLPATH>:$PATH" ' >> $HOME/.bashrc
        echo 'export PATH="<INSTALLPATH>:$PATH" ' >> $HOME/.bash_profile
        
        
        if [ -f "$HOME/.bashrc" ]; then source $HOME/.bashrc; fi
        if [ -f "$HOME/.bash_profile" ] ; then source $HOME/.bash_profile; fi
        
        composer self-update
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
$install_bash_script =~ s|<INSTALLER>|$installer|g;
$install_bash_script =~ s|<COMPOSER_SETUP>|$composer|g;
$install_bash_script =~ s|<INSTALLPATH>|$installpath|g;
    
   
#---------------------
    $self->__apply_install($force_tag,$installpath, $install_bash_script);

return 1;

}
















##############
sub miniconda{
    ##########
    
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
    
    yes | conda update --all

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


    $self->__apply_install($force_tag,$installpath, $install_bash_script);
    
    return 1;
}



















#############
sub anaconda{
    #########
    
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
    yes | conda update --all

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

    
    $self->__apply_install($force_tag,$installpath, $install_bash_script);
   
    return 1;
}

























#########
sub cvx {
    #####
    
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
    
    $self->__apply_install($force_tag,$installpath, $install_bash_script);

return 1;
}

    
    
    
    
    
    


1;