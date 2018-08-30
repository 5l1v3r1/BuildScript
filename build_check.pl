#!/usr/bin/perl

# Notes
#
#        Names: jws-application-server-5.0.0.RHEL_CR1-RHEL7-x86_64.zip : <package>-<version>.<build>-<platform>-<arch>.<extension>
#               jws-application-servers-3.1.0-40.sun10.sparc64.zip     : <package>s-<version>-<build>.<platform>.<arch>.<extension>
#               jws-application-servers-3.1.0-SP1.DR1-RHEL6-i386.zip   : <package>s-<version>-<build>-<platform>.<arch>.<extension>
# 
use 5.10.0;

use strict;
use warnings;

no warnings 'experimental';

use LWP::UserAgent;
use Data::Dump qw(dump);

# objects
my $ua = LWP::UserAgent->new('Build Checker Requester 1.0');

# globals variables

my $DEBUG = 1;

my @REPOSITORIES_URLS = ("http://download.eng.brq.redhat.com/devel/candidates/JWS/to_be_deleted", "http://download.eng.brq.redhat.com/devel/candidates/jboss/webserver/", "http://download.eng.brq.redhat.com/devel/candidates/jboss/", "http://download.eng.bos.redhat.com/brewroot/packages");

my @RELEASES = ();

my @INFORMATIONS_ATTRIBUTES= qw(ARCHIVE DEVEL_ARCHIVE BUILD_NAME NAME VERSION RELEASE SUMMARY DISTRIBUTION VENDOR LICENSE PACKAGER GROUP OS ARCH "RPM" URL TIMESTAMP COMPILER DESCRIPTION ZIP_FILE ZIP_REMOTE_FILE ZIP_REMOTE_CHECKSUM_FILE ZIP_FILE_CHECKSUM ZIP_REMOTE_CHECKSUM DEVEL_ZIP_FILE DEVEL_ZIP_REMOTE_FILE DEVEL_ZIP_REMOTE_CHECKSUM_FILE DEVEL_ZIP_FILE_CHECKSUM DEVEL_ZIP_REMOTE_CHECKSUM);

# call main
main();

sub main {
    my $dependency_argument = $ARGV[0] or die("Usage: perl $0 <package.ext>\n");
    get_repositories_urls();
    
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

sub get_repositories_urls {
    my $base_url = 'http://www.qa.jboss.com/xbuildroot/packages/';
    my $response = $ua->get($base_url);
    
    if($response && $response->content) {
        my @matches = $response->content =~ m/href="([^"\/]*)\/"/sgi;
        foreach my $match (@matches) {
            push(@RELEASES, $match);
            push(@REPOSITORIES_URLS, $base_url . $match);
        }
    }
    
    if($DEBUG) {
        foreach my $url (@REPOSITORIES_URLS) {
            print " [+] Repository found: $url\n";
        }
        print "\n";
    }
}

sub parse_name {
    my ( $name ) = @_;
    my $informations = { name => $name };
    my $regex = qr/([^\.]*)-([0-9]+\.[0-9a-z\.]*)[\-\.]([^\-\.]*(?:[\-\.]?[^\-\.]*)?)[\-\.]([^\.\-]*(?:[\-\.]?[^\-\.]*)?)[\-\.]([^\.]*)\.(zip|rpm)/i;
    
    if($name =~ /$regex/) {
        ($informations->{package}, $informations->{version}, $informations->{build}, $informations->{platform}, $informations->{arch}, $informations->{extension}) = $name =~ /$regex/i if($name =~ /$regex/);
    }
    
    return $informations;
}

sub get_package_informations {
    my ( $package ) = @_;
    my $command = 0;
    my $package_name = $package->{name};
    my $path = $package->{version} . '-' . $package->{build} . '.' . $package->{platform} . '-' . $package->{arch};
    $path =~ s/\-/\//gi;
    $path = '/' . $package->{package} . '/' . $path . '/';
    
    my @remote_checksum_urls = ();
    my @paths_variations = ($path);
    
    if($package->{package} =~ /jws-(?:application-servers?|httpd|src|docs|examples)/i) {
        push(@paths_variations, '/JWS-' . $package->{version} . '-' . $package->{build} . '/');
        push(@paths_variations, '/JWS-DIST-' . $package->{version} . '-' . $package->{build} . '/');
    } elsif($package->{package} =~ /jboss-ews-(?:application-servers?|httpd|src|docs|examples)/i) {
        push(@paths_variations, '/JBEWS-' . $package->{version} . '-' . $package->{build} . '/');
    } elsif($package->{package} =~ /jboss-eap/i) {
        push(@paths_variations, '/JBEAP-' . $package->{version} . '-' . $package->{build} . '/');
    }
    
    foreach my $url (@REPOSITORIES_URLS) {
        last if($package->{url});
        
        foreach my $path_variation (@paths_variations) {
            last if($package->{url});
            
            my $final_url = $url . $path_variation;
            print " * Trying $final_url ...\n" if($DEBUG);
            my $response = $ua->get($final_url);
            
            if($response && $response->is_success) {
                my $package_url = $final_url . $package->{package} . '-' . $package->{version} . '-' . $package->{build} . '.' . $package->{platform} . '.' . $package->{arch} . '.' . $package->{extension};
                $response = $ua->get($package_url);
                if(!$response || !$response->is_success) {
                    $package_url = $final_url . $package->{package} . '-' . $package->{version} . '-' . $package->{build} . '-' . $package->{platform} . '-' . $package->{arch} . '.' . $package->{extension};
                    $response = $ua->get($package_url);
                    
                    if($response && $response->is_success) {
                        $package->{url} = $package_url;
                    }
                } else {
                    $package->{url} = $package_url;
                }
                print " [FOUND] " . $package->{url} . "\n\n" if($DEBUG && $package->{url});
                
                push(@remote_checksum_urls, $url . $path_variation . 'MD5SUM');
                push(@remote_checksum_urls, $package->{url} . '.md5');
            }
        }
    }
    
    if($package->{url}) {
        if(0+@remote_checksum_urls) {
            foreach my $remote_checksum_url (@remote_checksum_urls) {
                last if($package->{remote_checksum_url});
                my $response = $ua->get($remote_checksum_url);
                
                if($response && $response->content) {
                    $package->{remote_checksum_url} = $remote_checksum_url;
                    ($package->{remote_checksum}) = $response->content =~ /([a-f0-9]+)\s+$package_name/i;
                    
                    if($DEBUG) {
                        print " [+] Remote checksum url/value found : " . $package->{remote_checksum_url} . "\n";
                        print "                            Checksum : " . $package->{remote_checksum} . "\n\n";    
                    }
                }
            }
        }
    }
    
    $package->{local_file} = "/tmp/" . $package->{name};
    
    print " * Downloading the archive file ...\n" if($DEBUG);
    system("wget '" . $package->{url} . "' -O " . $package->{local_file} . " 2>/dev/null") if(!-f $package->{local_file});
    
    my $local_checksum = `md5sum $package->{local_file}`;
    if($local_checksum) {
        chomp($local_checksum);
        ($package->{local_checksum}) = $local_checksum =~ /^([a-f0-9]+)\s/i;
        print " [MD5SUM] Local: " . $package->{local_checksum} . "\n" if($DEBUG);
    }
    
    if(lc($package->{extension}) eq 'zip') {
        $command = '/usr/bin/zipinfo -z "' . $package->{local_file} . '"';
    } elsif(lc($package->{extension}) eq 'rpm') {
        $command = 'rpm -q "' . $package->{local_file} . '" --info';
    } else {
        error("Unexpected extension: " . $package->{extension});
    }
    $package->{INFORMATIONS} = get_archive_informations($command, $package->{local_file}) if($command);
    system("rm -rf " . $package->{local_file});
    
    if(defined($package->{INFORMATIONS}->{DEPENDENCIES_PACKAGES}) && 0+@{ $package->{INFORMATIONS}->{DEPENDENCIES_PACKAGES} }) {
        foreach my $dependency_package (@{ $package->{INFORMATIONS}->{DEPENDENCIES_PACKAGES} }) {
            $package->{DEPENDENCIES}->{$dependency_package} = get_package_informations(parse_name($dependency_package . '.' . $package->{platform} . '.' . $package->{arch} . '.' . $package->{extension}));
        }
    }

    return $package;
}

sub get_archive_informations {
    my ( $command, $file ) = @_;
    
    my $informations = {};
    
    if(-f $file) {
        my $last_item = 0;
        my @output = `$command 2> /dev/null`;
        
        foreach my $line (@output) {
            chomp $line;
            last if($line =~ /Zip file size/i);
            
            if($line =~ /DEPENDENCIES:\s*(.*)[A-Z]+:.*/i) {
                my ($dependencies_string, $item, $value) = $line =~ /DEPENDENCIES:\s*(.*)[A-Z]+:(.*)/i;
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
        error("File doesn't exists: " . $file);
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
