=pod

=encoding utf-8

=head1 PURPOSE

Test that Role::Inspector works with Moo::Role.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2014 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;
use Test::Modern -requires => { 'Moo::Role' => '1.000000' };

use Role::Inspector qw( get_role_info );

is_deeply(
	get_role_info('Local::MooRole'),
	+{
		name  => 'Local::MooRole',
		type  => 'Moo::Role',
		api   => [sort qw( attr set_attr clear_attr _assert_attr delegated meth req )],
	},
	'can inspect Moo roles',
) or diag explain(get_role_info('Local::MooRole'));

done_testing;

