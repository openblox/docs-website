#!/usr/bin/env perl

# Generates stub pages for undocumented Instances
# Copyright (C) 2019 John M. Harris, Jr. <johnmh@johnmh.me>

use strict;
use warnings;

use XML::LibXML;

sub show_usage(){
    print "Usage: $0 PATH_TO_DOXYGEN_XML_DIR\n";
    exit(1);
}

if($#ARGV < 0){
    print "Not enough arguments.\n";
    show_usage();
}elsif($#ARGV > 0){
    print "Too many arguments.\n";
    show_usage();
}

my $xmlpath = $ARGV[0];
my $xmlindex = $xmlpath . "/index.xml";
my $indexDOM;

# This could be changed to an argument
my $classContentPath = "content/class/";

if(-e $xmlindex){
    $indexDOM = XML::LibXML->load_xml(location => $xmlindex) or die("No valid index.xml in the supplied path.");
}else{
    print "Invalid XML path\n";
    exit(1);
}

sub write_strub_file{
    my ($classFileName, $className, $doxy_compound) = @_;

    my $classXMLFile = $xmlpath . "$doxy_compound->{refid}.xml";

    my $classDOM = XML::LibXML->load_xml(location => $classXMLFile) or die("Failed to parse $classXMLFile");
    my $doxy_compounddef = $classDOM->findnodes("//compounddef[\@id=\"$doxy_compound->{refid}\"]")->get_node(1);
    my $parentClassName = substr($doxy_compounddef->findvalue("./basecompoundref"), 14);

    print "Generating stub page for $className\n";

    my $fh;
    open($fh, ">", $classFileName) or die("Failed to open file $classFileName");
    print $fh "---
title: \"$className\"
superclass: \"$parentClassName\"
---

This page is an automatically generated stub. The properties/methods listed on this page may not be accurate.

If you are familiar with this class, consider adding it to the [api documentation](https://git.openblox.org/openblox/api-documentation/).

<!-- THIS PAGE WAS AUTOMATICALLY GENERATED BY generate-stubs.pl -->
";
    close($fh);
    
}

foreach my $doxy_compound ($indexDOM->findnodes("//compound")){
    my $className = $doxy_compound->findvalue("./name");
    if(rindex($className, "OB::Instance::", 0) == 0){
        $className = substr($className, 14);
        # Omit _PropertyInfo and any subclasses
        if($className ne "_PropertyInfo" && index($className, "::") == -1){
            my $classFileName = $classContentPath . $className . ".md";
            if(-e $classFileName){
                my $cfh;
                open($cfh, $classFileName) or die("Failed to open file $classFileName");
                while(<$cfh>){
                    if($_ =~ /<!-- THIS PAGE WAS AUTOMATICALLY GENERATED BY generate-stubs.pl -->/){
                       write_strub_file($classFileName, $className, $doxy_compound);
                    }
                }
                close($cfh);
            }else{
                write_strub_file($classFileName, $className, $doxy_compound);
            }
        }
    }
}
