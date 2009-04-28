package BrownCS::udb::Model::DB;

use strict;
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
    schema_class => 'BrownCS::udb::Schema',
    connect_info => [
        'dbi:Pg:dbname=udb;host=sysdb',
        'aleks',
        'NohR0kei',
        
    ],
);

=head1 NAME

BrownCS::udb::Model::DB - Catalyst DBIC Schema Model
=head1 SYNOPSIS

See L<BrownCS::udb>

=head1 DESCRIPTION

L<Catalyst::Model::DBIC::Schema> Model using schema L<BrownCS::udb::Schema>

=head1 AUTHOR

Aleks Bromfield

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
