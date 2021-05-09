#!/usr/bin/env perl

# This program is a free software. You are free to use it under the terms of
# GNU GPL license either version 3 or, at your choice, any later version.
# Copyright 2019, 2020, 2021 Lucas V. Araujo <lucas.vieira.ar@disroot.org>

use strict;
use threads;
use warnings;
use HTTP::Tiny;
use File::Copy;
use File::Temp;
use PDF::Create;
use File::Fetch;
use Getopt::Long;
use Thread::Queue;
use Image::Magick;
use File::Basename;
use threads::shared;
use File::Path qw(make_path remove_tree);

use vars qw ($VERSION);

$VERSION = "2021.0509.0726";

my ($pdf, $remove, $silent, $queue, $threads, $root, $sti, $ident);
my $errors :shared;

sub request
{
    my ($url) = @_;
    my $resp = HTTP::Tiny->new()->get($url);
    $resp->{success} ? $resp->{content} : ""
}

sub update_status
{
    my ($msg, $done) = @_;
    my @status = split //, "\|/-";
    return if $silent;
    
    if ($done)
    {
        print "\b[DONE]\n";
    }
    elsif ($msg)
    {
        $sti = 0;
        $ident = length($msg) unless $ident && $ident >= length($msg);
        print "[+] $msg", " " x abs($ident - length($msg)), "\\";
        $| ++;
    }
    else
    {
        print "\b$status[$sti]";
        $| ++;
        $sti = ($sti + 1) % @status;
        sleep(0.5);
    }
}

sub thread_download
{
    my ($save_to) = @_;
    while (defined(my $link = $queue->dequeue()))
    {
        if (my $fetch = File::Fetch->new(uri => $link))
        {
            $fetch->fetch(to => "$save_to/") && next;
        }
        lock($errors);
        $errors ++;
    }
}

sub build_pdf
{
    my ($base, $path, $title, $chapter) = @_;
    update_status("Buildig PDF");
    my $pdf = PDF::Create->new(
        'filename'      => "${base}/${title} - ${chapter}.pdf",
        'Author'        => getlogin(),
        'Title'         => "$title - $chapter",
        'CreationDate'  => [ localtime ]
    );
    update_status();
    my $size = $pdf->get_page_size('A4');
    update_status();
    my $page = $pdf->new_page('MediaBox' => $size);
    update_status();
    for my $img (glob("$path/*.jpg"))
    {
        my $new_page = $page->new_page();
        my $page_img = $pdf->image($img);
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
        update_status();
    }
    $pdf->close();
    update_status(0, 1);
    remove_tree($path) if $remove;
}

sub convert_images
{
    my ($path) = @_;
    update_status("Converting images");
    $queue = Thread::Queue->new(glob("$path/*.jpg"));
    $queue->end();
    async {
        while (defined(my $file = $queue->dequeue()))
        {
            my $img = Image::Magick->new();
            $img->Read($file);
            $img->Set(compression => 0);
            my $tmpname = tmpnam() . "." . basename($file);
            $img->Write($tmpname);
            move($tmpname, $file);
        }
    } for 1 .. $threads;
    while (threads->list(threads::running) > 0)
    {
        update_status();
    }
    map { $_->join() } threads->list(threads::all);
    update_status(0, 1);
}

sub download_chapter
{
    my ($base, $chapter, $title) = @_;
    update_status("Downloading chapter $chapter     ");
    my $html = request("$base/$chapter");
    my $path = "$root/$title/$chapter";
    $path = (make_path($path))[-1] unless -d $path;
    my @links = $html =~ /<img src="([^"]+)".+pag="\d+"[^>]+>/ig;
    $queue = Thread::Queue->new(map { $_ =~ s/ /%20/gr } @links);
    $queue->end();
    async { thread_download($path) } for 1 .. $threads;
    while (threads->list(threads::running) > 0)
    {
        update_status();
    }
    map { $_->join() } threads->list(threads::all);
    update_status(0,1);
    $path
}

sub get_chapters
{
    my ($url) = @_;
    my $html = request($url);
    $html =~ /<option class='listCap' value='([^']+)'/ig
}

sub help
{
    print <<HELP;
${\basename($0)} - Download de HQs através do site hqdragon.com
Uso: ${\basename($0)} [opções] <hq_url>
Opções:

    -h, --help      Exibe esta mensagem de ajuda e sai
    -v, --version   Exibe a versão do programa e sai
    -d, --dest      Caminho para salvar os downloads
    -p, --pdf       Criar PDF dos capítulos baixados
    -s, --silent    Não exibir informações de status
    -r, --remove    Remover scans depois de criar o PDF
    -t, --threads   Número de tarefas paralelas para baixar cada capítulo

Exemplo:

    ${\basename($0)} --pdf -r https://hqdragon.com/leitor/Supergirl_(1996)/01

Esta é uma ferramenta destinada a realizar downloads de HQs
através do site HQDragon <https://hqdragon.com/>.
No entanto, o desenvolvedor desta ferramenta não possui nenhuma
relação com o site e/ou com os administradores do mesmo.
Copyright (C) 2020 Lucas V. Araujo <lucas.vieira.ar\@disroot.org>
GitHub: https://github.com/lvmalware/hqdragon-download

HELP
    exit(0);
}

sub version
{
    print $VERSION, "\n";
    exit(0);
}

sub main
{
    $root = ".";
    $errors = 0;
    $threads = 5;
    $File::Fetch::WARN = 0;
    GetOptions(
        "p|pdf"         => \$pdf,
        "h|help"        => \&help,
        "d|dest=s"      => \$root,
        "s|silent"      => \$silent,
        "r|remove"      => \$remove,
        "v|version"     => \&version,
        "t|threads=i"   => \$threads,
    );
    my $url = shift @ARGV;
    
    unless ($url)
    {
        print "Uso: ${\basename($0)} [opções] <hq_url>\n";
        print "Execute '${\basename($0)}' --help para ver as opções\n";
        exit(0);
    }
    
    if ($url =~ /https\:\/\/hqdragon\.com\/([^\/]+)\/([^\/]+)\/([^\/]+)/i)
    {
        my ($mode, $title, $chapter) = ($1, $2, $3);
        if ($mode eq 'hq')
        {
            update_status("Getting info                            ");
            my $html = request($url);
            next unless $html =~ /(https\:\/\/hqdragon\.com\/(leitor)\/([^\/]+)\/([^\/]+))/i;
            ($url, $mode, $title, $chapter) = ($1, $2, $3, $4);
            update_status(0, 1);
        }
        my $base = substr($url, 0, rindex($url, "/"));
        update_status("Getting chapters                        ");
        my @chapters = get_chapters($url);
        update_status(0, 1);
        for my $chap (@chapters)
        {
            my $path = download_chapter($base, $chap, $title);
            if ($pdf)
            {
                convert_images($path);
                build_pdf("$root/$title", $path, $title, $chap);
            }
        }
    }
    
    $errors > 0;
}

exit main unless caller;