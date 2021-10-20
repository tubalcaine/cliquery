#!/usr/bin/perl -w
use strict;

use XML::LibXML::SAX;
use XML::Simple;
use XML::SAX;
use XML::SAX::Expat;
use XML::SAX::PurePerl;
use LWP::UserAgent;
use LWP::Protocol::https;
use Data::Dumper;
#use HTTP::Cookies;
use HTTP::Request;
use URI::Escape;
use JSON;
use Term::ReadKey;

print STDERR "IBM BigFix Client Relevance Query\n";
print STDERR "Version 1.0\n\n";

my $config = XMLin();

die "No configuration XML file. Must have same name as program with .xml extension.\n" unless (defined $config);

if (scalar @ARGV != 1) {
	print STDERR "Usage: checkAnswers <query ID>\n";
	exit 1;
}

## Allow password prompting for safety!
if (!defined ($config->{bespassword})) {
	print STDERR "No password set for user [$config->{besuser}]. Please type\n";
	print STDERR "that password here (it will not echo):";
	ReadMode("noecho");
	$config->{bespassword} = ReadLine(0);
	chomp $config->{bespassword};
	print STDERR "\nThank you.\n\n";
	ReadMode("restore");
}

my $reqID = $ARGV[0];

my $lwp = LWP::UserAgent->new( keep_alive => 1 );

## Remove the SSL cert and name validation
$lwp->{ssl_opts}->{SSL_verify_mode} = 0;
$lwp->{ssl_opts}->{verify_hostname} = 0;

my $cliQueryURL = "https://" . $config->{server} . ":" . $config->{port} . "/api/clientqueryresults/$reqID";

my $clistreq = HTTP::Request->new( GET => $cliQueryURL );

$clistreq->authorization_basic($config->{besuser}, $config->{bespassword});

my $cliReqResult = $lwp->request($clistreq);

if (!$cliReqResult->is_success) {
	print STDERR "HTTP POST Error code: [" . $cliReqResult->code . "]\n";
	print STDERR "HTTP POST Error msg:  [" . $cliReqResult->message . "]\n";
	exit 1;
}

my $clires = XMLin($cliReqResult->decoded_content, ForceArray => [ 'QueryResult' ]);

my $computer = {};

foreach (@{$clires->{ClientQueryResults}->{QueryResult}}) {
	my $curRes = $_;
	
	$computer->{$curRes->{ComputerName}}->{Result} .= $curRes->{Result} . "\n";
	$computer->{$curRes->{ComputerName}}->{ResponseTime} += $curRes->{ResponseTime};
}

foreach (keys %{$computer}) {
	print "Computer Name: [$_]:\n";
	print "Time: [$computer->{$_}->{ResponseTime}]\n";
	foreach (split /\n/, $computer->{$_}->{Result}) {
		print "\t$_\n";
	}
}

exit 0;

