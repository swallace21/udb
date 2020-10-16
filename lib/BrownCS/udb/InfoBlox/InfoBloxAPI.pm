#!/usr/bin/perl

package BrownCS::udb::InfoBlox::InfoBloxAPI;

use strict;
use warnings FATAL => 'all';
use feature qw( say );

use 5.010;

use LWP::UserAgent;
use HTTP::Request::Common;
use JSON::MaybeXS ();
use JSON::XS qw( decode_json );
use Data::Dumper;

use YAML::Tiny;

=head1 DESCRIPTION

InfoBlox

Stores functions related to InfoBlox to manage IPs and machines in Marston Hall.

Authorship: Shaun Wallace (sw90)


RESOURCES:

infoflox examples
https://community.infoblox.com/t5/API-Integration/Get-Next-Available-IP-and-Reserve/td-p/8548

good example
https://stackoverflow.com/questions/4199266/how-can-i-make-a-json-post-request-with-lwp

api examples:
https://www.infoblox.com/wp-content/uploads/infoblox-deployment-infoblox-rest-api.pdf

###

Build JSON response per request

Get new UserAgent ($ua)

Build $URL

Build GET/POST with URL

Authorize Request

Initial Call to get Response

Extract data from Response and Send back

=cut

#####################
####### Global Vars
my $User;
my $Pass;
my $Network_test = "10.9.1.0/24";
my $Network = "10.9.114.0/24";
my $Base_url = "https://gm.brown.edu/wapi";
my $Api_vers = "v2.10.1";
my $Grid = "grid/b25lLmNsdXN0ZXIkMA:Infoblox";
my $Json = JSON::MaybeXS->new(utf8 => 1, pretty => 1);

# sw: bypass SSL cert check bc something is wrong with their cert
my $UA = new LWP::UserAgent; 
$UA->ssl_opts( verify_hostname => 0, SSL_verify_mode => 0x00);


#####################
####### MAIN Function
sub main() {
    ### get credentials from yaml file
    get_credentials();
    
}

#####################
####### SubRoutines

sub get_credentials() {
    my $INFOBLOX_CONFIG = "/sysvol/secure-cfg/infoblox.yml";
    my $config_yaml = YAML::Tiny->read($INFOBLOX_CONFIG) || die "Can't open $INFOBLOX_CONFIG\n";
    my $creds = $config_yaml->[0];
    return ($creds->{user}, $creds->{pass});
}

sub build_url {
     my $api_url = shift;
    return "$Base_url/$Api_vers/$api_url";
}

sub build_request {
    my ($rest_method,$url,$data_json) = @_;
    
    my $request;
    if($rest_method eq "POST") {
        $request = POST($url);
    } elsif($rest_method eq "GET") {
        $request = GET($url);
    }
    $request->header( 'Content-Type' => 'application/json' );
    $request->content( $data_json );

    my($usr, $pass) = get_credentials();
    $request->authorization_basic($usr, $pass);

    return $request;
}

sub run_request {
    my ($rest_method,$api_url,$data_json) = @_;

    my $url = build_url($api_url);
    my $request = build_request($rest_method,$url,$data_json);
    
    my $response = $UA->request($request);

    if ($response->is_success) {
        return $response;
    } else {
        print "\nERROR with InfoBlox...\n";
        print STDERR $response->status_line, "\n";
        die;
    }
}

sub get_next_avail_ip {
    my ($macaddr,$hostname,$new_fixed_ip) = @_;

    my $data_json = "{
        \"ipv4addr\":\"func:nextavailableip:$new_fixed_ip\",
        \"mac\":\"$macaddr\",
        \"name\":\"$hostname\",
        \"options\" : [{ \"name\": \"host-name\", \"value\": \"$hostname\" }]
    }";

    my $api_url = "fixedaddress?_return_fields%2B=ipv4addr,mac&_return_as_object=1";
    
    my $response = run_request("POST",$api_url,$data_json);

    my $json = decode_json($response->content);

    while ( my ($key, $val) = each(%{$json->{result}}) ) {
        if($key eq "ipv4addr") {
            return $val;   
        }
    }

    post_dhcp_restart();
}

sub post_fixed_ip {
    my ($macaddr,$hostname) = @_;

    my $data_json = "{
        \"ipv4addr\":\"$Network\",
        \"mac\":\"$macaddr\",
        \"name\":\"$hostname\",
        \"options\" : [{ \"name\": \"host-name\", \"value\": \"$hostname\" }]
    }";

    my $api_url = "fixedaddress?_return_fields%2B=ipv4addr,mac&_return_as_object=1";
    
    my $response = run_request("POST",$api_url,$data_json);

    my $json = decode_json($response->content);

    while ( my ($key, $val) = each(%{$json->{result}}) ) {
        if($key eq "ipv4addr") {
            return $val;   
        }
    }

    post_dhcp_restart();
}

sub post_dhcp_restart() {
    my $data_json = '{"member_order":"SIMULTANEOUSLY","service_option": "DHCP"}';

    my $api_url = "$Grid?_function=restartservices";
    
    my $response = run_request("POST",$api_url,$data_json);
    #print Dumper($response->as_string());
}

sub get_grid_name() {
    my $data_json = "";

    my $api_url = "grid";
    
    my $response = run_request("GET",$api_url,$data_json);
    #print Dumper($response->content);
    
    # get grid name
    foreach my $element ( @{ decode_json($response->content) } ) {
        while ( my ($key, $val) = each(%$element) ) {
            if($key eq "_ref") {
                return $val;
            }
        }
    }
}

sub get_hosts() {
    my $data_json = "";

    my $api_url = "record:host?_return_as_object=1";
    
    my $response = run_request("GET",$api_url,$data_json);
    #print Dumper($response->content);

    my $json = decode_json($response->content);

    say Dumper($json->{result});

    foreach my $element ( @{ $json->{result} } ) {
        while ( my ($key, $val) = each(%$element) ) {
            if($key eq "_ref" || $key eq "name") {
                say $key . " : "  . $val;
            } elsif($key eq "ipv4addrs") {
                foreach my $ip_hash ( @{ $val } ) {
                    while ( my ($key2, $val2) = each(%$ip_hash) ) {
                        say "   " . $key2 . " : "  . $val2;
                    }
                }
            }
        }
        say "";
    }
}

sub get_ip_address_info {
    my ($ip) = @_;
    my $data_json = '{}';
    my $api_url = "search?address=$ip&_return_as_object=1";
    my $response = run_request("GET",$api_url,$data_json);
    my $json = decode_json($response->content);

    foreach my $element ( @{ $json->{result} } ) {
        while ( my ($key, $val) = each(%$element) ) {
            if(($key eq "_ref" || $key eq "name") && (strContains($val,"ipv4address"))) {
                say $val;
            }
        }
    }
}

sub post_fixed_avail_ip {
    my ($ip,$macaddr,$hostname) = @_;

    my $data_json = "{ 
        \"ipv4addr\":\"$ip\", 
        \"mac\":\"$macaddr\", 
        \"name\":\"$hostname\",
        \"options\" : [{ \"name\": \"host-name\", \"value\": \"$hostname\" }]
    }";

    my $api_url = "fixedaddress?_return_fields%2B=ipv4addr,mac&_return_as_object=1";
    
    my $response = run_request("POST",$api_url,$data_json);

    if($response) { # sw need to test
        post_dhcp_restart();
    }
}

sub check_if_dhcp_requires_restart() {
    say "shaun... we still need to debug this";
    #die;

    my $data_json = "";

    my $api_url = "record:host?_return_as_object=1";
    
    my $response = run_request("GET",$api_url,$data_json);
    #print Dumper($response->content);

    my $json = decode_json($response->content);

    my $requires_restart = 0;

    foreach my $element ( @{ $json->{result} } ) {
        while ( my ($key, $val) = each(%$element) ) {
            if($key eq "name") {
                say "\n" . $val;
            }
            if($key eq "ipv4addrs") {
                foreach my $ip_hash ( @{ $val } ) {
                    while ( my ($key2, $val2) = each(%$ip_hash) ) {
                        # configure_for_dhcp : 1
                        say "   " . $key2 . " : "  . $val2;
                        if($key2 eq "configure_for_dhcp" && $val2) {
                            $requires_restart = 1;
                        }
                    }
                }
            }
        }
    }
    say "requires_restart = $requires_restart";

    if($requires_restart) {
        #post_dhcp_restart();
        say "\nrestart university dhcp...? YES";
    } else {
        say "\nrestart university dhcp...? NO";
    }
}

check_if_dhcp_requires_restart();
