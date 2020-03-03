#!/usr/bin/perl

# This program is a free software. You are free to use it under the terms of
# GNU GPL license either version 3 or, at your choice, any later version.
# Copyright 2019 Lucas V. Araujo <lucas.vieira.ar@disroot.org>

use strict;
use warnings;
use HTTP::Tiny;
use File::Fetch;
use Getopt::Long;

use vars qw ($VERSION);

$VERSION = "2020.0101.2056";

sub request
{
    my $resp = HTTP::Tiny->new()->get($_[0]);
    return $resp->{content} if ($resp->{success});
    ""
}

sub main
{
    my $ver   = 0;
    my $help  = 0;
    GetOptions ("help"    => \$help,
                "version" => \$ver
                );
    if ($ver)
    {
        print "$VERSION\n";
        exit(0);
    }
    if ($help)
    {
        print "hqdragon-dl - Download de HQs através do site hqdragon.com\n" .
        "Uso: hqdragon-dl.pl [opções] <hq_url>\n\n" .
        "Opções:\n" .
        "-v, --version  exibe a versão do programa e sai\n" .
        "-h, --help     exibe esta mensagem de ajuda e sai\n" .
        "Exemplo: \n" .
        "hqdragon-dl.pl https://hqdragon.com/leitor/Supergirl_(1996)/01\n\n" .
        "Esta é uma ferramenta destinada a realizar downloads de HQs\n" .
        "através do site HQDragon <https://hqdragon.com/>.\n" .
        "No entanto, o desenvolvedor desta ferramenta não possui nenhuma\n" .
        "relação com o site e/ou com os administradores do mesmo.\n\n" .
        "Copyright (C) 2020 Lucas V. Araujo <lucas.vieira.ar\@disroot.org>\n" .
        "GitHub: https://github.com/lvmalware/hqdragon-download\n\n";
        exit(0);
    }
    my $url   = shift @ARGV;
    unless ($url)
    {
        print "Uso: hqdragon-dl.pl [opções] <hq_url>\n" .
        "Tente -h ou --help para mais detalhes.\n";
        exit(1);
    }
    my $title;
    my $dummy;

    if ($url  =~ /https\:\/\/hqdragon\.com\/leitor\/(.*)\/(\d*\/?)$/)
    {
        $title = $1;
        $dummy = $2;
    }
    else
    {
        print "Erro: A url fornecida é inválida.\n";
        exit(1);
    }
    unless (-d "$title")
    {
        system("mkdir '$title'");
    }
    
    $url      =~ s/\/$dummy\/?// if ($dummy);
    my $html  = request("$url\/01");
    
    while ($html =~ /<option class='listCap' value='([\w\d]*)'/ig)
    {
        my $index = $1;
        my $new   = request("$url\/$index");
        system("mkdir -p '$title\/$index'");
        print "[+] Downloading chapter $index ...\n";
        while ($new =~ /<img src="(https\:\/\/.*(\d+\.jpg))" class\="img\-/ig)
        {
            
            my $file_url  = $1;
            my $file_name = $2;
            $file_url     =~ s/ /%20/g;
            my $out_file  = "$title/$index";
            my $f_fetch   = File::Fetch->new(uri => $file_url);
            if ($f_fetch)
            {
                my $where     = $f_fetch->fetch(to => $out_file);
                print "[+] Downloaded $file_name\n";
            }
            else
            {
                print "[-] Failed to download $file_name\n";
            }
            
        };
        print "-"x80 . "\n";
    }
    
    print "\nDone.\n";
}

main();
