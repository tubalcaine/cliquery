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

my $lwp = LWP::UserAgent->new( keep_alive => 1 );

## Remove the SSL cert and name validation
$lwp->{ssl_opts}->{SSL_verify_mode} = 0;
$lwp->{ssl_opts}->{verify_hostname} = 0;

my $query = $config->{query};

my $rawquery = $query;

$query = uri_escape($query);

my $cliQueryURL = "https://" . $config->{server} . ":" . $config->{port} . "/api/clientquery";

while (<>) {
	chomp;
	my $cliquery = << "END_TEXT";
	<BESAPI xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation=\"BESAPI.xsd\">
	  <ClientQuery>
	  <ApplicabilityRelevance>true</ApplicabilityRelevance>
	  <QueryText>$_</QueryText>
	  </ClientQuery>
	</BESAPI>
END_TEXT
	
	my $clistreq = HTTP::Request->new( POST => $cliQueryURL );
	$clistreq->header('content-type' => 'application/x-www-form-urlencoded');
	$clistreq->content($cliquery);
	
	$clistreq->authorization_basic($config->{besuser}, $config->{bespassword});
	
	my $cliReqResult = $lwp->request($clistreq);
	
	if (!$cliReqResult->is_success) {
		print STDERR "HTTP POST Error code: [" . $cliReqResult->code . "]\n";
		print STDERR "HTTP POST Error msg:  [" . $cliReqResult->message . "]\n";
		exit 1;
	}
	
	my $clires = XMLin($cliReqResult->decoded_content);
	
	print "$clires->{ClientQuery}->{ID}\n";
}

exit 0;
