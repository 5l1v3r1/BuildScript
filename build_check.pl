#!/usr/bin/perl

use 5.10.0;

use strict;
use warnings;

no warnings 'experimental';

use LWP::UserAgent;
use Data::Dump qw(dump);

# objects
my $ua = LWP::UserAgent->new('Build Checker Requester 1.0');

# globals static variables
my @REPOSITORIES_URLS = ("http://www.qa.jboss.com/xbuildroot/packages/ep6.4","http://www.qa.jboss.com/xbuildroot/packages/jws3.1","http://www.qa.jboss.com/xbuildroot/packages/jbcs2.4.27","http://download.eng.bos.redhat.com/brewroot/packages");

my @INFORMATIONS_ATTRIBUTES= qw(ARCHIVE DEVEL_ARCHIVE BUILD_NAME NAME VERSION RELEASE SUMMARY DISTRIBUTION VENDOR LICENSE PACKAGER GROUP OS ARCH "RPM" URL TIMESTAMP COMPILER DESCRIPTION ZIP_FILE ZIP_REMOTE_FILE ZIP_REMOTE_CHECKSUM_FILE ZIP_FILE_CHECKSUM ZIP_REMOTE_CHECKSUM DEVEL_ZIP_FILE DEVEL_ZIP_REMOTE_FILE DEVEL_ZIP_REMOTE_CHECKSUM_FILE DEVEL_ZIP_FILE_CHECKSUM DEVEL_ZIP_REMOTE_CHECKSUM);

# call main
main();

sub main {
    my $dependency_argument = $ARGV[0] or die("Usage: perl $0 <package.ext>\n");
    
    if($dependency_argument) {
        my $package = parse_name($dependency_argument);
        if($package->{package} && $package->{version} && $package->{build} && $package->{arch} && $package->{extension}) {
            $package = get_package_informations($package);
            print dump($package);
        } else {
            error("Couldn't extract package informations from: $dependency_argument");
        }
    } else {
        error("Missing package argument .\n");
    }
}

sub parse_name {
    my ( $name ) = @_;
    my $informations = { name => $name };
    my $regex = qr/^([^\.]*)-([0-9]+\.[0-9a-z\.]*)-([^\-\.]*)[-\.](.+)\.([^\.]*)\.(zip|rpm)$/i;
    
    if($name =~ /$regex/) {
        ($informations->{package}, $informations->{version}, $informations->{build}, $informations->{platform}, $informations->{arch}, $informations->{extension}) = $name =~ /$regex/i if($name =~ /$regex/);
    }
    
    return $informations;
}

sub get_package_informations {
    my ( $package ) = @_;
    my $path = $package->{version} . '-' . $package->{build} . '.' . $package->{platform} . '-' . $package->{arch};
    
    $path =~ s/\-/\//gi;
    $path = '/' . $package->{package} . '/' . $path . '/';
    
    foreach my $url (@REPOSITORIES_URLS) {
        last if($package->{url});
        $url .= $path;
#        print " * Trying $url ...\n";
        my $response = $ua->get($url);
        
        if($response->is_success) {
            $package->{url} = $url . $package->{package} . '-' . $package->{version} . '-' . $package->{build} . '.' . $package->{platform} . '.' . $package->{arch} . '.' . $package->{extension};
#            print "[FOUND] " . $package->{url} . "\n\n";
        }
    }
    
    $package->{local_file} = "/tmp/" . $package->{name};
    system("wget '" . $package->{url} . "' -O " . $package->{local_file}) if(!-f $package->{local_file});
    
    if(lc($package->{extension}) eq 'zip') {
        $package->{INFORMATIONS} = get_zip_informations($package->{local_file});
    } elsif(lc($package->{extension}) eq 'rpm') {
        
    }
    
    if(defined($package->{INFORMATIONS}->{DEPENDENCIES_PACKAGES}) && 0+@{ $package->{INFORMATIONS}->{DEPENDENCIES_PACKAGES} }) {
        foreach my $dependency_package (@{ $package->{INFORMATIONS}->{DEPENDENCIES_PACKAGES} }) {
            $package->{DEPENDENCIES}->{$dependency_package} = get_package_informations(parse_name($dependency_package . '.' . $package->{platform} . '.' . $package->{arch} . '.' . $package->{extension}));
        }
    }

    return $package;
}

sub get_zip_informations {
    my ( $file ) = @_;
    
    my $informations = {};
    
    if(-e "/usr/bin/zipinfo" && -f $file) {
        my $last_item = 0;
        my @output = `/usr/bin/zipinfo -z $file 2> /dev/null`;
        
        foreach my $line (@output) {
            chomp $line;
            last if($line =~ /Zip file size/i);
            
            if($line =~ /DEPENDENCIES: (.*)[A-Z]+:.*/i) {
                my ($dependencies_string, $item, $value) = $line =~ /DEPENDENCIES: (.*)[A-Z]+:(.*)/i;
                $informations->{DEPENDENCIES} = $dependencies_string;
                $informations->{$item} = $value;
                $last_item = $item;
            } elsif($line =~ /^([^\:]*):\s*(.*)/i) {
                my ($item, $value) = split(/:\s*/, $line);
                $value =~ s/\t//gi;
                $value =~ s/\s\s+/ /gi;
                
                $informations->{$item} = $value;
                $last_item = $item;
            } else {
                $informations->{$last_item} .= $line if($last_item);
            }
        }
        
        if(defined($informations->{DEPENDENCIES}) && $informations->{DEPENDENCIES}) {
            foreach my $dependency_package (split(/,\s*/, $informations->{DEPENDENCIES})) {
                push(@{ $informations->{DEPENDENCIES_PACKAGES} }, $dependency_package);
            }
        } else {
            @{ $informations->{DEPENDENCIES_PACKAGES} } = ();
        }
        
    } else {
        error("zipinfo not found .\n");
    }
    
    return $informations;
}

sub not_in_array {
    my ( $value, $ref_array ) = @_;
    my $not_in_array = 1;
    
    my @array = @{ $ref_array };
    
    if(defined($value) && $value) {
        if (grep { $value eq $_ } @array) {
            $not_in_array = 0;
        }
    } else {
        return 0;
    }
    
    return $not_in_array;
}

sub error {
    my ( $text ) = @_;
    
    print "[ERROR] $text\n";
}
