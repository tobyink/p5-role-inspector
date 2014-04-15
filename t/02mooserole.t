=pod

=encoding utf-8

=head1 PURPOSE

Test that Role::Inspector works with Moose::Role.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2014 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;
use Test::Modern -requires => { 'Moose::Role' => '2.0600' };

use Role::Inspector get_role_info => { no_meta => 1 };

is_deeply(
	get_role_info('Local::MooseRole'),
	+{
		name     => 'Local::MooseRole',
		type     => 'Moose::Role',
		api      => [sort qw( meta attr set_attr clear_attr delegated meth req )],
		requires => [sort qw( req )],
		provides => [sort qw( meta attr set_attr clear_attr delegated meth )],
	},
	'can inspect Moose roles',
) or diag explain(get_role_info('Local::MooseRole'));

done_testing;

