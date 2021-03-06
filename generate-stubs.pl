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

# This needs to be updated with the C++ types that we expose as Lua properties
my @supportedTypes = ("bool", "double", "int", "float", "std::string", "shared_ptr< Type::Vector3 >", "shared_ptr< Type::Color3 >", "shared_ptr< Type::UDim2 >", "shared_ptr< Instance >", "shared_ptr< Type::LuaEnumItem >");

sub cppToLuaType{
    my $cppType = $_[0];
    
    if($cppType eq "std::string"){
        return "string";
    }elsif($cppType eq "shared_ptr< Type::Vector2 >"){
        return "Vector2";
    }elsif($cppType eq "shared_ptr< Type::Vector3 >"){
        return "Vector3";
    }elsif($cppType eq "shared_ptr< Type::Color3 >"){
        return "Color3";
    }elsif($cppType eq "shared_ptr< Type::UDim2 >"){
        return "UDim2";
    }elsif($cppType eq "shared_ptr< Instance >"){
        return "Instance";
    }elsif($cppType eq "shared_ptr< Type::LuaEnumItem >"){
        return "Enum";
    }elsif($cppType eq "shared_ptr< Player >"){
        return "Player";
    }elsif($cppType eq "bool"){
        return "bool";
    }elsif($cppType eq "int"){
        return "int";
    }elsif($cppType eq "float"){
        return "float";
    }elsif($cppType eq "double"){
        return "double";
    }elsif($cppType eq "void"){
        return "void";
    }else{
        print "Unsupported type: $cppType\n";
        return "void";
    }
}

print "Checking index.xml\n";

if(-e $xmlindex){
    $indexDOM = XML::LibXML->load_xml(location => $xmlindex) or die("No valid index.xml in the supplied path.");
}else{
    print "Invalid XML path\n";
    exit(1);
}

sub isCamelCase{
    if($_[0] =~ /^[[:upper:]]/){
        return 1;
    }else{
        return 0;
    }
}

sub write_strub_file{
    my ($classFileName, $className, $doxy_compound) = @_;

    my $classXMLFile = $xmlpath . "/$doxy_compound->{refid}.xml";

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

If you are familiar with this class, consider adding it to the [api documentation](https://git.openblox.org/openblox/api-documentation/).\n";

    my @propList;
    my @methodList;
    my @eventList;

    foreach my $prop ($doxy_compounddef->findnodes("//memberdef[\@kind=\"variable\"]")){
        my $propName = $prop->findvalue("./name");
        my $propType = $prop->findvalue("./type");

        if(isCamelCase($propName)){
            if($propType eq "shared_ptr< Type::Event >"){
                push @eventList, "\n{{% event $propName %}}\n";
            }elsif($propType ~~ @supportedTypes){
                my $convertedType = cppToLuaType($propType);
                push @propList, "\n{{% property $convertedType $propName %}}\n";
            }else{
                print "Unsupported type: $propType\n";
            }
        }
    }

    foreach my $method ($doxy_compounddef->findnodes("//memberdef[\@kind=\"function\"]")){
        my $methodName = $method->findvalue("./name");
        my $retType = $method->findvalue("./type");
        my $argString = substr($method->findvalue("./argsstring"), 1, -1);

        if(isCamelCase($methodName) && ($methodName ne $className) && ($methodName ne "DECLARE_CLASS") && ($methodName ne "DECLARE_LUA_METHOD")){
            my $convertedType = cppToLuaType($retType);
            push @methodList, "\n{{% method $convertedType $methodName \"$argString\" %}}\n";
        }
    }

    if(scalar @propList > 0){
        print $fh "\n## Properties\n";

        foreach my $propInfo (@propList){
            print $fh $propInfo;
        }
    }

    if(scalar @methodList > 0){
        print $fh "\n## Methods\n";

        foreach my $methodInfo (@methodList){
            print $fh $methodInfo;
        }
    }

    if(scalar @eventList > 0){
        print $fh "\n## Events\n";

        foreach my $eventInfo (@eventList){
            print $fh $eventInfo;
        }
    }
    
    print $fh "\n<!-- THIS PAGE WAS AUTOMATICALLY GENERATED BY generate-stubs.pl -->\n";
    close($fh);
    
}

print "Building stub pages...\n";

foreach my $doxy_compound ($indexDOM->findnodes("//compound")){
    my $className = $doxy_compound->findvalue("./name");
    if(rindex($className, "OB::Instance::", 0) == 0){
        $className = substr($className, 14);

        # Omit _PropertyInfo and any subclasses
        if($className ne "_PropertyInfo" && index($className, "::") == -1){
            my $classFileName = $classContentPath . "/" . $className . ".md";
            if(-e $classFileName){
                my $cfh;
                open($cfh, $classFileName) or die("Failed to open file $classFileName");
                while(<$cfh>){
                    if($_ =~ /<!-- THIS PAGE WAS AUTOMATICALLY GENERATED BY generate-stubs.pl -->/){
                        write_strub_file($classFileName, $className, $doxy_compound);
                        last;
                    }
                }
                close($cfh);
            }else{
                write_strub_file($classFileName, $className, $doxy_compound);
            }
        }
    }
}
