=pod

=encoding utf-8

=head1 PURPOSE

Test that Role::Inspector works with Mouse::Role.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2014 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

use strict;
use warnings;
use Test::Modern -requires => { 'Mouse::Role' => '1.00' };

use Role::Inspector get_role_info => { no_meta => 1 };

is_deeply(
	get_role_info('Local::MouseRole'),
	+{
		name  => 'Local::MouseRole',
		type  => 'Mouse::Role',
		api   => [sort qw( meta attr set_attr clear_attr delegated meth req )],
	},
	'can inspect Mouse roles',
) or diag explain(get_role_info('Local::MouseRole'));

done_testing;

