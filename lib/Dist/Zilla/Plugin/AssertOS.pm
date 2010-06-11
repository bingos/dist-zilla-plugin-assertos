package Dist::Zilla::Plugin::AssertOS;

# ABSTRACT: Require that our distribution is running on a particular OS

use Moose;
with 'Dist::Zilla::Role::FileGatherer';

use Devel::CheckOS qw[list_platforms];
use File::Spec;

sub mvp_multivalue_args { qw/os/ }

has 'os' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
    auto_deref => 1,
);

sub gather_files {
  my $self = shift;
  
  require Data::Compare;

  foreach my $os ( $self->os ) {
    my $oldinc = { map { $_ => $INC{$_} } keys %INC }; # clone
    eval "use Devel::AssertOS qw($os)";
    if(Data::Compare::Compare(\%INC, $oldinc)) {
        print STDERR "Couldn't find a module for $os\n";
        exit(1);
    }
  }

  my @modulefiles = keys %{{map { $_ => $INC{$_} } grep { /Devel/i && /(Check|Assert)OS/i } keys %INC}};

  foreach my $modulefile (@modulefiles) {
    my $fullfilename = '';
    SEARCHINC: foreach (@INC) {
        if(-e File::Spec->catfile($_, $modulefile)) {
            $fullfilename = File::Spec->catfile($_, $modulefile);
            last SEARCHINC;
        }
    }
    die("Can't find a file for $modulefile\n") unless(-e $fullfilename);

    (my $module = join('::', split(/\W+/, $modulefile))) =~ s/::pm/.pm/;
    my @dircomponents = ('inc', (split(/::/, $module)));
    my $file = pop @dircomponents;

    { 
      open(my $PM, $fullfilename) ||
        die("Can't read $fullfilename: $!");
      local $/ = undef;
      (my $content = <$PM>) =~ s/package Devel::/package #\nDevel::/;
      close($PM);
      
      my $pm = Dist::Zilla::File::InMemory->new({
         content => $content,
         name    => File::Spec->catfile(@dircomponents, $file),
      });

      $self->add_file($pm);

    }
  }
  warn $_, "\n" for $self->zilla->files;
  return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

qq[run run Reynard]

__END__

=head1 NAME

Dist::Zilla::Plugin::AssertOS - Require that our distribution is running on a particular OS

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 ATTRIBUTES

=head2 METHODS

=over

=item C<gather_files>

=item C<mvp_multivalue_args>

=back

=head1 AUTHOR

Chris C<BinGOs> Williams

Based on L<use-devel-assertos> by David Cantrell

=head1 LICENSE

Copyright E<copy> Chris Williams and David Cantrell

This module may be used, modified, and distributed under the same terms as Perl itself. Please see the license that came with your Perl distribution for details.

=head1 SEE ALSO

L<Dist::Zilla>

L<Devel::AssertOS>

L<Devel::CheckOS>

=cut

