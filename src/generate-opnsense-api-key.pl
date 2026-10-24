#!/usr/bin/env perl
#
# Generate an API key/secret for an OPNsense user (default: root).
#
# Targets the MVC user manager (System > Access > Users, /ui/auth/user).
# The legacy system_usermanager.php page is gone, so instead of scraping the
# user edit page we log in with a web session and call the API endpoint that
# the new UI itself uses:
#
#   POST /api/auth/user/add_api_key/<username>
#   -> {"result":"ok","hostname":"...","key":"...","secret":"..."}
#
# Session-authenticated API calls need the CSRF token the UI injects into its
# pages (X-CSRFToken header), so we scrape that from the page first.

use strict;
use warnings;
use WWW::Mechanize ();
use Getopt::Std;
use JSON::PP ();
use URI::Escape qw(uri_escape);

my %opts = (
    H => "192.168.1.1",                     # OPNsense host (host or host:port)
    u => "root",                            # OPNsense username
    p => "opnsense",                        # OPNsense password
    f => "/root/keys/.opnsense-api-key.json",    # Output file
    q => 0,                                 # Quiet mode
);
getopts('H:u:p:f:q', \%opts);

my $base = "https://$opts{H}";

sub login {
    my $mech = shift;

    $mech->get("$base/");

    # Don't rely on the page title or form name; the login form is the one
    # with username + password fields. Hidden fields (CSRF) are carried over
    # by Mechanize automatically.
    my $form = $mech->form_with_fields(qw(usernamefld passwordfld));
    if ($form) {
        $mech->field(usernamefld => $opts{u});
        $mech->field(passwordfld => $opts{p});
        if ($form->find_input('login', 'submit')) {
            $mech->click('login');
        }
        else {
            $mech->submit();
        }
    }

    # Open the new user manager; if we get the login form again, login failed.
    $mech->get("$base/ui/auth/user");
    die "Login failed (still seeing the login form)\n"
      if $mech->form_with_fields(qw(usernamefld passwordfld));
}

sub find_csrf_header {
    my $html = shift;

    # $.ajaxSetup({ beforeSend: function (xhr) {
    #     xhr.setRequestHeader("X-CSRFToken", "...") } })
    while ($html =~ /setRequestHeader\(\s*(["'])(.+?)\1\s*,\s*(["'])(.+?)\3\s*\)/g) {
        my ($name, $value) = ($2, $4);
        next unless lc($name) eq 'x-csrftoken';
        $value =~ s{\\/}{/}g;    # un-escape JSON-style slashes
        return ($name, $value);
    }

    # Fallback: headers: { "X-CSRFToken": "..." }
    if ($html =~ /["'](X-CSRFToken)["']\s*:\s*["']([^"']+)["']/i) {
        my ($name, $value) = ($1, $2);
        $value =~ s{\\/}{/}g;
        return ($name, $value);
    }
    return;
}

sub generate_api_key {
    my $mech = shift;

    my ($name, $value) = find_csrf_header($mech->content());
    die "Failed to find the X-CSRFToken header in the page; "
      . "is this a recent OPNsense with the MVC user manager?\n"
      unless defined $name;

    $mech->add_header(
        $name              => $value,
        'X-Requested-With' => 'XMLHttpRequest',
        'Accept'           => 'application/json',
    );

    my $url = "$base/api/auth/user/add_api_key/" . uri_escape($opts{u});
    my $res = eval {
        $mech->post(
            $url,
            'Content-Type' => 'application/json',
            Content        => '{}',
        );
    };
    die "API request to $url failed: " . ($@ || $mech->status()) . "\n"
      unless $res && $res->is_success;

    my $body = $res->decoded_content;
    my $data = eval { JSON::PP->new->decode($body) };
    die "Unexpected response from $url:\n$body\n"
      unless ref $data eq 'HASH'
      && ($data->{result} // '') eq 'ok'
      && defined $data->{key}
      && defined $data->{secret};

    # The secret is only shown once, so keep the file private.
    my $old_umask = umask(0077);
    open(my $fh, '>', $opts{f}) || die "Cannot write $opts{f}: $!\n";
    print $fh $body, "\n";
    close($fh) || die "Cannot write $opts{f}: $!\n";
    umask($old_umask);
    chmod 0600, $opts{f};

    print "API key saved to $opts{f}\n" unless $opts{q};
}

sub main {
    my $mech = WWW::Mechanize->new(
        ssl_opts => {SSL_verify_mode => 0, verify_hostname => 0},
        autocheck => 1,
    );
    login($mech);
    generate_api_key($mech);
    exit 0;
}

main();

1;
