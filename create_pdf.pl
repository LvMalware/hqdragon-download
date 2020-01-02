#!/usr/bin/perl

# This program is a free software. You are free to use it under the terms of
# GNU GPL license either version 3 or, at your choice, any later version.
# Copyright 2019 Lucas V. Araujo <lucas.vieira.ar@disroot.org>
# Required module: PDF::Create

use strict;
use warnings;
use PDF::Create;
use File::Glob ':bsd_glob';

sub create_pdf
{
    my $root_dir = shift;
    for my $dir (bsd_glob("$root_dir/*"))
    {
        if (-d "$dir")
        {
            print "Creating PDF for $dir...\n";
            my $title   = `basename "$root_dir"`;
            my $chapter = `basename "$dir"`;
            my $pdf = PDF::Create->new(
                'filename'      => "$dir.pdf",
                'Author'        => `whoami`,
                'Title'         => "$title - $chapter",
                'CreationDate'  => [ localtime ]
            );
            my $size = $pdf->get_page_size('A4');
            my $page = $pdf->new_page('MediaBox' => $size);
            for my $img (bsd_glob("$dir/*.jpg"))
            {
                my $new_page = $page->new_page();
                my $page_img = $pdf->image("$img");
                my $xscale   = $size->[2] / $page_img->{'width'};
                my $yscale   = $size->[3] / $page_img->{'height'};
                $new_page->image(
                    image   => $page_img,
                    xscale  => $xscale,
                    yscale  => $yscale,
                    xpos    => 0,
                    ypos    => 840,
                    xalign  => 0,
                    yalign  => 2
                );
                print "Added image $img\n";
            }
            $pdf->close();
            print "\n\n";
        }
    }
}

my $root_dir = shift @ARGV;
unless ($root_dir)
{
    print "Usage: create_pdf.pl <hq_directory>\n";
    exit(0);
}

unless (-d "$root_dir")
{
    print "Diretório inválido ou não encontrado.\n";
    exit(1);
}

create_pdf($root_dir);
print "-"x80;
print "\nDone.\n";
