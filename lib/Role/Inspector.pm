use 5.006;
use strict;
use warnings;

package Role::Inspector;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.003';

use Exporter::Shiny qw( get_role_info learn );
use Module::Runtime qw( use_package_optimistically );
use Scalar::Util qw( blessed );

our @SCANNERS;

sub learn (&)
{
	push @SCANNERS, $_[0];
}

sub get_role_info
{
	my $me = shift;
	use_package_optimistically($_[0]);
	my ($info) = grep defined, map $_->(@_), @SCANNERS;
	return $info;
}

sub _generate_get_role_info
{
	my $me = shift;
	my ($name, $args, $globals) = @_;
	return sub {
		my $info = $me->get_role_info(@_);
		delete($info->{meta}) if $args->{no_meta};
		return $info;
	};
}

sub _expand_attributes
{
	my $me = shift;
	my ($role, $meta) = @_;
	
	my @attrs = map {
		my $data = $meta->get_attribute($_);
		$data->{name} = $_ unless exists($data->{name});
		$data;
	} $meta->get_attribute_list;
	my %methods;
	
	for my $attr (@attrs)
	{
		my $is = blessed($attr) && $attr->can('is') ? $attr->is : $attr->{is};
		$methods{blessed($attr) && $attr->can('name') ? $attr->name : $attr->{name} }++
			if $is =~ /\A(ro|rw|lazy|rwp)\z/i;
		
		for my $method_type (qw(reader writer accessor clearer predicate))
		{
			my $method_name = blessed($attr) ? $attr->$method_type : $attr->{$method_type};
			($method_name) = %$method_name if ref($method_name); # HASH :-(
			$methods{$method_name}++ if defined $method_name;
		}
		
		my $handles;
		if (blessed($attr) and $attr->can('_canonicalize_handles'))
		{
			$handles =
				$attr->can('_canonicalize_handles') ? +{ $attr->_canonicalize_handles } :
				$attr->can('handles') ? $attr->handles :
				$attr->{handles};
		}
		else
		{
			$handles = $attr->{handles};
		}
		
		if (!defined $handles)
		{
			# no-op
		}
		elsif (not ref($handles))
		{
			$methods{$_}++ for @{ $me->get_info($handles)->{api} };
		}
		elsif (ref($handles) eq q(ARRAY))
		{
			$methods{$_}++ for @$handles;
		}
		elsif (ref($handles) eq q(HASH))
		{
			$methods{$_}++ for keys %$handles;
		}
		else
		{
			require Carp;
			Carp::carp(
				sprintf(
					"%s contains attribute with delegated methods, but %s cannot determine which methods are being delegated",
					$role,
					$me,
				)
			);
		}
	}
	
	return keys(%methods);
}

# Learn about mop
learn {
	my $role = shift;
	return unless $INC{'mop.pm'};
	
	my $meta = mop::meta($role);
	return unless $meta && $meta->isa('mop::role');
	
	return {
		name   => $role,
		type   => 'mop::role',
		api    => [
			sort
			map( $_->name, $meta->methods ),
			$meta->required_methods,
		],
		meta   => $meta,
	};
};

# Learn about Role::Tiny and Moo::Role
learn {
	my $role = shift;
	return unless $INC{'Role/Tiny.pm'};
	
	# Moo 1.003000 added is_role, but that's too new to rely on.
	my @methods;
	return unless eval {
		@methods = 'Role::Tiny'->methods_provided_by($role);
		1;
	};
	
	no warnings qw(once);
	my $type =
		($INC{'Moo/Role.pm'} and $Moo::Role::INFO{$role}{accessor_maker})
		? 'Moo::Role'
		: 'Role::Tiny';
	
	@methods = $type->methods_provided_by($role)
		if $type ne 'Role::Tiny';
	
	return {
		name   => $role,
		type   => $type,
		api    => [ sort(@methods) ],
	};
};

# Learn about Moose
learn {
	my $role = shift;
	return unless $INC{'Moose.pm'};
	
	require Moose::Util;
	my $meta = Moose::Util::find_meta($role);
	return unless $meta && $meta->isa('Moose::Meta::Role');
	
	return {
		name   => $role,
		type   => 'Moose::Role',
		api    => [
			sort
			map($_->name, $meta->get_required_method_list),
			$meta->get_method_list,
			__PACKAGE__->_expand_attributes($role, $meta),
		],
		meta   => $meta,
	};
};

# Learn about Mouse
learn {
	my $role = shift;
	return unless $INC{'Mouse.pm'};
	
	require Mouse::Util;
	my $meta = Mouse::Util::find_meta($role);
	return unless $meta && $meta->isa('Mouse::Meta::Role');
	
	return {
		name   => $role,
		type   => 'Mouse::Role',
		api    => [
			sort
			$meta->get_required_method_list,
			$meta->get_method_list,
			__PACKAGE__->_expand_attributes($role, $meta),
		],
		meta   => $meta,
	};
};

# Learn about Role::Basic
learn {
	my $role = shift;
	return unless $INC{'Role/Basic.pm'};
	
	return unless eval { 'Role::Basic'->_load_role($role) };
	
	return {
		name   => $role,
		type   => 'Role::Basic',
		api    => [
			sort
			'Role::Basic'->get_required_by($role),
			keys(%{ 'Role::Basic'->_get_methods($role) })
		],
	};
};

1;

__END__

=pod

=encoding utf-8

=for stopwords metaobject

=head1 NAME

Role::Inspector - introspection for roles

=head1 SYNOPSIS

   use strict;
   use warnings;
   use feature qw(say);
   
   {
      package Local::Role;
      use Role::Tiny;   # or Moose::Role, Mouse::Role, etc...
      
      requires qw( foo );
      
      sub bar { ... }
   }
   
   use Role::Inspector qw( get_role_info );
   
   my $info = get_role_info('Local::Role');
   
   say $info->{name};          # Local::Role
   say $info->{type};          # Role::Tiny
   say for @{$info->{api}};    # bar
                               # foo

=head1 DESCRIPTION

This module allows you to retrieve a hashref of information about a
given role. The following role implementations are supported:

=over

=item *

L<Moose::Role>

=item *

L<Mouse::Role>

=item *

L<Moo::Role>

=item *

L<Role::Tiny>

=item *

L<Role::Basic>

=item *

L<p5-mop-redux|https://github.com/stevan/p5-mop-redux>

=back

=head2 Functions

=over

=item C<< get_role_info($package_name) >>

Returns a hashref of information about a role; returns C<undef> if the
package does not appear to be a role. Attempts to load the package
using L<Module::Runtime> if it's not already loaded.

The hashref may contain the following keys:

=over

=item *

C<name> - the package name of the role

=item *

C<type> - the role implementation used by the role

=item *

C<api> - an arrayref of method names required/provided by the role

=item *

C<meta> - a metaobject for the role (e.g. a L<Moose::Meta::Role> object).
This key may be absent if the role implementation does not provide a
metaobject.

=back

This function may be exported, but is not exported by default. If you do
not wish to export it, you may call it as a class method:

   Role::Inspector->get_role_info($package_name)

=item C<< Role::Inspector::learn { BLOCK } >>

In the unlikely situation that you have to deal with some other role
implementation that Role::Inspector doesn't know about, you can teach
it:

   use Role::Inspector qw( learn );
   
   learn {
      my $r = shift;
      return unless My::Implementation::is_role($r);
      return {
         name  => $r,
         type  => 'My::Implementation',
         api   => [
            sort(
               @{ My::Implementation::required_methods($r) },
               @{ My::Implementation::provided_methods($r) },
            )
         ],
      };
   };

An alternative way to do this is:

   push @Role::Inspector::SCANNERS, sub {
      my $r = shift;
      ...;
   };

You can do the C<push> thing without having loaded Role::Inspector.
This makes it suitable for doing inside My::Implementation itself,
without introducing an additional dependency on Role::Inspector.

=back

=head1 CAVEATS

=over

=item *

It is difficult to distinguish between L<Moo::Role> and L<Role::Tiny>
roles. (The distinction is not often important anyway.) Thus sometimes
the C<type> for a Moo::Role may say C<< "Role::Tiny" >>.

=item *

The way that Role::Basic roles are detected and introspected is a bit
dodgy, relying on undocumented methods.

=item *

Where Moose or Mouse roles define attributes, those attributes tend to
result in accessor methods being generated. However neither of these
frameworks provides a decent way of figuring out which accessor methods
will result from composing the role with the class.

Role::Inspector does its damnedest to figure out the list of likely
methods, but (especially in the case of unusual attribute traits) may
get things wrong from time to time.

=back

=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue=Role-Inspector>.

=head1 SEE ALSO

L<Class::Inspector>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2014 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

